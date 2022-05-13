#!/bin/bash
set -e

while getopts s:d:r: args
do
    case "${args}" in
        s) SCANNING_BUCKET_NAME=${OPTARG};;
        d) DEPLOYMENT_NAME_PREFIX=${OPTARG};;
        r) REGION=${OPTARG};;
    esac
done

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)
ARTIFACT_BUCKET_NAME='fss-artifact'-$(cat /proc/sys/kernel/random/uuid)

DEPLOYMENT_NAME_SCANNER=$DEPLOYMENT_NAME_PREFIX'-scanner'
DEPLOYMENT_NAME_STORAGE=$DEPLOYMENT_NAME_PREFIX'-storage'

printInfo() {
  echo "Scanning bucket name: $SCANNING_BUCKET_NAME";
  echo "Artifact bucket name: $ARTIFACT_BUCKET_NAME";
  echo "Scanner Deployment Name: $DEPLOYMENT_NAME_SCANNER";
  echo "Storage Deployment Name: $DEPLOYMENT_NAME_STORAGE";
  echo "GCP Project ID: $GCP_PROJECT_ID";
  echo "Region: $REGION";
}

printInfo
echo "Will deploy file storage security protection unit, Ctrl-C to cancel..."
sleep 5

PREVIEW_BUCKET_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
TEMPLATES_FILE='gcp-templates.zip'
LISTENER_FILE='gcp-listener.zip'
SCANNER_FILE='gcp-scanner.zip'
SCANNER_DLT_FILE='gcp-scanner-dlt.zip'
ACTION_TAG_FILE='gcp-action-tag.zip'

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

prepareArtifact $LISTENER_FILE
prepareArtifact $SCANNER_FILE
prepareArtifact $SCANNER_DLT_FILE
prepareArtifact $ACTION_TAG_FILE

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

sed -i "s/region:.*/region: $REGION/" templates/storage.yaml
sed -i "s/artifactBucket:.*/artifactBucket: $ARTIFACT_BUCKET_NAME/" templates/storage.yaml
sed -i "s/scanningBucket:.*/scanningBucket: $SCANNING_BUCKET_NAME/" templates/storage.yaml
sed -i "s/scannerTopic:.*/scannerTopic: $SCANNER_TOPIC/" templates/storage.yaml
sed -i "s/scannerProjectID:.*/scannerProjectID: $SCANNER_PROJECT_ID/" templates/storage.yaml
sed -i "s/scannerServiceAccountID:.*/scannerServiceAccountID: $SCANNER_SERVICE_ACCOUNT_ID/" templates/storage.yaml
cat templates/storage.yaml

# Deploy storage service account template
gcloud deployment-manager deployments create $DEPLOYMENT_NAME_STORAGE --config templates/storage-service-account-role.yaml

gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_STORAGE --format "json" >> $DEPLOYMENT_NAME_STORAGE"-role".json

searchStorageRoleJSONOutputs() {
  cat $DEPLOYMENT_NAME_STORAGE"-role".json | jq -r --arg v "$1" '.outputs[] | select(.name==$v).finalValue'
}

BUCKET_LISTENER_ROLE_ID=$(searchStorageRoleJSONOutputs bucketListenerRoleID)
POST_ACTION_TAG_ROLE_ID=$(searchStorageRoleJSONOutputs postActionTagRoleID)

sed -i "s/blRoleID:.*/blRoleID: $BUCKET_LISTENER_ROLE_ID/" templates/storage.yaml
sed -i "s/patRoleID:.*/patRoleID: $POST_ACTION_TAG_ROLE_ID/" templates/storage.yaml
cat templates/storage.yaml

# Update storage template
gcloud deployment-manager deployments update $DEPLOYMENT_NAME_STORAGE --config templates/storage.yaml

gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_STORAGE --format "json" >> $DEPLOYMENT_NAME_STORAGE.json

searchStorageJSONOutputs() {
  cat $DEPLOYMENT_NAME_STORAGE.json | jq -r --arg v "$1" '.outputs[] | select(.name==$v).finalValue'
}

STORAGE_PROJECT_ID=$(searchStorageJSONOutputs storageProjectID)
BUCKET_LISTENER_SERVICE_ACCOUNT_ID=$(searchStorageJSONOutputs bucketListenerServiceAccountID)
SCAN_RESULT_TOPIC=$(searchStorageJSONOutputs scanResultTopic)

# Binding service account and role on Pub/Sub Topics.
gcloud pubsub topics add-iam-policy-binding $SCANNER_TOPIC --member="serviceAccount:$BUCKET_LISTENER_SERVICE_ACCOUNT_ID@$STORAGE_PROJECT_ID.iam.gserviceaccount.com" --role='roles/pubsub.publisher'
gcloud pubsub topics add-iam-policy-binding $SCAN_RESULT_TOPIC --member="serviceAccount:$SCANNER_SERVICE_ACCOUNT_ID@$SCANNER_PROJECT_ID.iam.gserviceaccount.com" --role='roles/pubsub.publisher'

# Remove the artifact bucket
gsutil rm -r gs://$ARTIFACT_BUCKET_NAME
rm -rf templates

echo "FSS Protection Unit Information:"
printInfo
