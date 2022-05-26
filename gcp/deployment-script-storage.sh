#!/bin/bash
set -e

while getopts s:d:r:i: args
do
    case "${args}" in
        s) SCANNING_BUCKET_NAME=${OPTARG};;
        d) DEPLOYMENT_NAME_STORAGE=${OPTARG};;
        r) REGION=${OPTARG};;
        i) SCANNER_INFO_JSON=${OPTARG};;
    esac
done

SCANNER_INFO_FILE='scanner-info'-$(cat /proc/sys/kernel/random/uuid).json
echo $SCANNER_INFO_JSON > $SCANNER_INFO_FILE
while IFS== read key value
do
    printf -v "$key" "$value"
done < <(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' $SCANNER_INFO_FILE)

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)
ARTIFACT_BUCKET_NAME='fss-artifact'-$(cat /proc/sys/kernel/random/uuid)

printInfo() {
  echo "Scanning bucket name: $SCANNING_BUCKET_NAME";
  echo "Artifact bucket name: $ARTIFACT_BUCKET_NAME";
  echo "Scanner info JSON: $SCANNER_INFO_JSON"
  echo "Storage Deployment Name: $DEPLOYMENT_NAME_STORAGE";
  echo "GCP Project ID: $GCP_PROJECT_ID";
  echo "Region: $REGION";
}

printInfo
echo "Will deploy file storage security protection unit storage stack, Ctrl-C to cancel..."
sleep 5

PREVIEW_BUCKET_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
TEMPLATES_FILE='gcp-templates.zip'
LISTENER_FILE='gcp-listener.zip'
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
prepareArtifact $ACTION_TAG_FILE

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

printStorageInfo() {
  STORAGE_INFO=$(jq --null-input \
    --arg storageProjectID "$STORAGE_PROJECT_ID" \
    --arg deploymentNameStorage "$DEPLOYMENT_NAME_STORAGE" \
    '{"STORAGE_PROJECT_ID": $storageProjectID, "DEPLOYMENT_NAME_STORAGE": $deploymentNameStorage}')
  echo $STORAGE_INFO > $DEPLOYMENT_NAME_STORAGE-storage-info.json
  cat $DEPLOYMENT_NAME_STORAGE-storage-info.json
}

echo "FSS Protection Unit Information:"
printInfo
printStorageInfo
