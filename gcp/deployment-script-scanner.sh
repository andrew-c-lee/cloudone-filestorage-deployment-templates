#!/bin/bash
set -e

while getopts d:r: args
do
    case "${args}" in
        d) DEPLOYMENT_NAME_SCANNER=${OPTARG};;
        r) REGION=${OPTARG};;
    esac
done

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)
ARTIFACT_BUCKET_NAME='fss-artifact'-$(cat /proc/sys/kernel/random/uuid)

printInfo() {
  echo "Artifact bucket name: $ARTIFACT_BUCKET_NAME";
  echo "Scanner Deployment Name: $DEPLOYMENT_NAME_SCANNER";
  echo "GCP Project ID: $GCP_PROJECT_ID";
  echo "Region: $REGION";
}

printInfo
echo "Will deploy file storage security protection unit scanner stack, Ctrl-C to cancel..."
sleep 5

PREVIEW_BUCKET_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
TEMPLATES_FILE='gcp-templates.zip'
SCANNER_FILE='gcp-scanner.zip'
SCANNER_DLT_FILE='gcp-scanner-dlt.zip'

# Check Project Setting
gcloud deployment-manager deployments list > /dev/null

# Download the templates package
wget $PREVIEW_BUCKET_URL'gcp-templates/'$TEMPLATES_FILE

# Unzip the templates package
unzip $TEMPLATES_FILE && rm $TEMPLATES_FILE

# Create an artifact Google Cloud Storage bucket
gsutil mb --pap enforced -b on gs://$ARTIFACT_BUCKET_NAME

prepareArtifact() {
  # Download FSS functions artifacts
  wget $PREVIEW_BUCKET_URL'cloud-functions/'$1
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

# Update scanner template
gcloud deployment-manager deployments update $DEPLOYMENT_NAME_SCANNER --config templates/scanner.yaml

gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_SCANNER --format "json" >> $DEPLOYMENT_NAME_SCANNER.json

searchScannerJSONOutputs() {
  cat $DEPLOYMENT_NAME_SCANNER.json | jq -r --arg v "$1" '.outputs[] | select(.name==$v).finalValue'
}

SCANNER_TOPIC=$(searchScannerJSONOutputs scannerTopic)
SCANNER_TOPIC_DLT=$(searchScannerJSONOutputs scannerTopicDLT)
SCANNER_PROJECT_ID=$(searchScannerJSONOutputs scannerProjectID)
SCANNER_SERVICE_ACCOUNT_ID=$(searchScannerJSONOutputs scannerServiceAccountID)

SCANNER_PROJECT_NUMBER=$(gcloud projects list --filter=$SCANNER_PROJECT_ID --format="value(PROJECT_NUMBER)")
PUBSUB_SERVICE_ACCOUNT="service-$SCANNER_PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com"
SUBSCRIPTIONS=$(gcloud pubsub topics list-subscriptions $SCANNER_TOPIC)
SCANNER_SUBSCRIPTION_ID=${SUBSCRIPTIONS#*/*/*/}

# Update scanner topic dead letter config
gcloud pubsub subscriptions update $SCANNER_SUBSCRIPTION_ID \
  --dead-letter-topic=$SCANNER_TOPIC_DLT \
  --max-delivery-attempts=5

# Binding Pub/Sub service account
gcloud pubsub topics add-iam-policy-binding $SCANNER_TOPIC_DLT \
    --member="serviceAccount:$PUBSUB_SERVICE_ACCOUNT"\
    --role="roles/pubsub.publisher"
gcloud pubsub subscriptions add-iam-policy-binding $SCANNER_SUBSCRIPTION_ID \
    --member="serviceAccount:$PUBSUB_SERVICE_ACCOUNT"\
    --role="roles/pubsub.subscriber"

# Remove the artifact bucket
gsutil rm -r gs://$ARTIFACT_BUCKET_NAME
rm -rf templates

printScannerInfo() {
  SCANNER_INFO=$(jq --null-input \
    --arg scannerTopic "$SCANNER_TOPIC" \
    --arg scannerProjectID "$SCANNER_PROJECT_ID" \
    --arg scannerSAID "$SCANNER_SERVICE_ACCOUNT_ID" \
    '{"SCANNER_TOPIC": $scannerTopic, "SCANNER_PROJECT_ID": $scannerProjectID, "SCANNER_SERVICE_ACCOUNT_ID": $scannerSAID}')
  echo $SCANNER_INFO > $DEPLOYMENT_NAME_SCANNER-scanner-info.json
  cat $DEPLOYMENT_NAME_SCANNER-scanner-info.json
}

echo "FSS Protection Unit Information:"
printInfo
printScannerInfo
