#!/bin/bash
set -e

while getopts d:r:u: args
do
  case "${args}" in
    d) DEPLOYMENT_NAME_SCANNER=${OPTARG};;
    r) REGION=${OPTARG};;
    u) PACKAGE_URL=${OPTARG};;
  esac
done

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)
ARTIFACT_BUCKET_NAME='fss-artifact'-$(cat /proc/sys/kernel/random/uuid)

echo "Artifact bucket name: $ARTIFACT_BUCKET_NAME";
echo "Scanner Deployment Name: $DEPLOYMENT_NAME_SCANNER";
echo "GCP Project ID: $GCP_PROJECT_ID";
echo "Region: $REGION";
echo "Package URL: $PACKAGE_URL";
echo "Will deploy file storage security protection unit scanner stack, Ctrl-C to cancel..."
sleep 5

if [ -z "$PACKAGE_URL" ]; then
  PACKAGE_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
fi

TEMPLATES_FILE='gcp-templates.zip'
SCANNER_FILE='gcp-scanner.zip'
SCANNER_DLT_FILE='gcp-scanner-dlt.zip'

# Check Project Setting
gcloud deployment-manager deployments list > /dev/null

# Download the templates package
wget $PACKAGE_URL'gcp-templates/'$TEMPLATES_FILE

# Unzip the templates package
unzip $TEMPLATES_FILE && rm $TEMPLATES_FILE

# Create an artifact Google Cloud Storage bucket
gsutil mb --pap enforced -b on gs://$ARTIFACT_BUCKET_NAME

prepareArtifact() {
  # Download FSS functions artifacts
  wget $PACKAGE_URL'cloud-functions/'$1
  # Upload functions artifacts to the artifact bucket
  gsutil cp $1 gs://$ARTIFACT_BUCKET_NAME/$1 && rm $1
}

prepareArtifact $SCANNER_FILE
prepareArtifact $SCANNER_DLT_FILE

sed -i "s/region:.*/region: $REGION/" templates/scanner.yaml
sed -i "s/artifactBucket:.*/artifactBucket: $ARTIFACT_BUCKET_NAME/" templates/scanner.yaml
cat templates/scanner.yaml

# Deploy scanner service account template
gcloud deployment-manager deployments create $DEPLOYMENT_NAME_SCANNER --config templates/scanner-service-account-role.yaml

SCANNER_DEPLOYMENT=$(gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_SCANNER --format "json")

searchScannerJSONOutputs() {
  echo $SCANNER_DEPLOYMENT | jq -r --arg v "$1" '.outputs[] | select(.name==$v).finalValue'
}

SCANNER_PROJECT_ID=$(searchScannerJSONOutputs scannerProjectID)
SCANNER_SERVICE_ACCOUNT_ID=$(searchScannerJSONOutputs scannerServiceAccountID)

SECRET_STRING=$( jq -n \
    --arg license '$eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJ3d3cudHJlbmRtaWNyby5jb20iLCJleHAiOjE2NjQ3Njk2MDAsIm5iZiI6MTY1NDA1MDU1NCwiaWF0IjoxNjU0MDUwNTU0LCJzdWIiOiJnY3AtcHJldmlldy1saWNlbnNlIiwiY2xvdWRPbmUiOnsiYWNjb3VudCI6IjU2NDUwNTA5NDE4NyJ9fQ.NTRBsm_A6dvG3BQIAZ2tX3IEcBmOD1jlFhf2AwfW_xaQcTnEYdrk5FT0-uG9lQf960j_l5olDWEEwVny7clzm7dhNOi3LqFOoF4h1_oly451u8LMmuj_rmm29hEA_5a4dYBtECkRZK5Pp0xw1chR7DaSz1_DGsLs5kqhdzyoiP3QGGy7vVhnYNHrZLhUNHrILr6ynJoPoSUlAz8szwZ7ZbTK9gMDfXCKVsy2afS0GTbzd4NhLqQf9bDSrNmBhcv3WWxRpSwA90i7V2V7xeOt8TFd22_GNe6uKDlpNYCZSE60f57_E23NgoPfcBAAo_h9r4ErhEEoWSAryWXr_cIpMwvhcNVvFmKNFraIkOP8l58v_2E85qxA_TrmJGd-kLcuoyE1IJVpZHJle6sAZEYyTwUBBxjs_N9nuHqSoO79pJj62VmED9XMsnqY8D8b8v8roazE5YqvPRgN5LqilCMeySQy1jJmmEiwl6k2z1-3SYKefr_j-Q1v_LpUJ9FudlylMLYyK9jUZXXDhO2jkd3zDt3xUybUpyh1CHmh9SYdZoW4yJrcVBvDI82s6quA4fL-akayoRRFHolveNDyUq78JoFwJBHJWMmrOcbAGSMfQfvYQs8Hq9_0ZnSYCIUjr4VxIWr2owWD87S9ISDSNscab03skfijAdEcVlZVIBa5MUo' \
    --arg fssAPIEndpoint 'https://filestorage.us-1.cloudone.trendmicro.com/api/' \
    '{LICENSE: $license, FSS_API_ENDPOINT: $fssAPIEndpoint}' )

# Create scanner secrets environment variable
echo -n "$SECRET_STRING" | \
  gcloud secrets create $DEPLOYMENT_NAME_SCANNER-scanner-secrets --data-file=-

# Allow scanner service account to access the secrets
gcloud secrets add-iam-policy-binding $DEPLOYMENT_NAME_SCANNER-scanner-secrets \
    --member="serviceAccount:$SCANNER_SERVICE_ACCOUNT_ID@$SCANNER_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

sed -i "s/<SCANNER_SECRETS>/$DEPLOYMENT_NAME_SCANNER-scanner-secrets/g" templates/scanner.yaml

# Update scanner template
gcloud deployment-manager deployments update $DEPLOYMENT_NAME_SCANNER --config templates/scanner.yaml

SCANNER_DEPLOYMENT=$(gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_SCANNER --format "json")

SCANNER_TOPIC=$(searchScannerJSONOutputs scannerTopic)
SCANNER_TOPIC_DLT=$(searchScannerJSONOutputs scannerTopicDLT)

SCANNER_PROJECT_NUMBER=$(gcloud projects list --filter=$SCANNER_PROJECT_ID --format="value(PROJECT_NUMBER)")
PUBSUB_SERVICE_ACCOUNT="service-$SCANNER_PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
SUBSCRIPTIONS=$(gcloud pubsub topics list-subscriptions $SCANNER_TOPIC)
SCANNER_SUBSCRIPTION_ID=${SUBSCRIPTIONS#*/*/*/}

# Update scanner topic dead letter config
gcloud pubsub subscriptions update $SCANNER_SUBSCRIPTION_ID \
    --dead-letter-topic=$SCANNER_TOPIC_DLT \
    --max-delivery-attempts=5

# Binding Pub/Sub service account
gcloud pubsub topics add-iam-policy-binding $SCANNER_TOPIC \
    --member="serviceAccount:$SCANNER_SERVICE_ACCOUNT_ID@$SCANNER_PROJECT_ID.iam.gserviceaccount.com" \
    --role='roles/pubsub.publisher'
gcloud pubsub topics add-iam-policy-binding $SCANNER_TOPIC_DLT \
    --member="serviceAccount:$PUBSUB_SERVICE_ACCOUNT"\
    --role="roles/pubsub.publisher"
gcloud pubsub subscriptions add-iam-policy-binding $SCANNER_SUBSCRIPTION_ID \
    --member="serviceAccount:$PUBSUB_SERVICE_ACCOUNT"\
    --role="roles/pubsub.subscriber"

# Remove the artifact bucket
gsutil rm -r gs://$ARTIFACT_BUCKET_NAME
rm -rf templates

printScannerJSON() {
  SCANNER_JSON=$(jq --null-input \
    --arg projectID "$SCANNER_PROJECT_ID" \
    --arg deploymentName "$DEPLOYMENT_NAME_SCANNER" \
    '{"projectID": $projectID, "deploymentName": $deploymentName}')
  echo $SCANNER_JSON > $DEPLOYMENT_NAME_SCANNER.json
  cat $DEPLOYMENT_NAME_SCANNER.json
}

printScannerInfo() {
  SCANNER_INFO=$(jq --null-input \
    --arg scannerTopic "$SCANNER_TOPIC" \
    --arg scannerProjectID "$SCANNER_PROJECT_ID" \
    --arg scannerSAID "$SCANNER_SERVICE_ACCOUNT_ID" \
    '{"SCANNER_TOPIC": $scannerTopic, "SCANNER_PROJECT_ID": $scannerProjectID, "SCANNER_SERVICE_ACCOUNT_ID": $scannerSAID}')
  echo $SCANNER_INFO > $DEPLOYMENT_NAME_SCANNER-info.json
  cat $DEPLOYMENT_NAME_SCANNER-info.json
}

echo "FSS Protection Unit Information:"
printScannerJSON
printScannerInfo
