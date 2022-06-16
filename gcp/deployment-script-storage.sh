#!/bin/bash
set -e

while getopts s:d:r:i:u:k:m: args
do
  case "${args}" in
    s) SCANNING_BUCKET_NAME=${OPTARG};;
    d) DEPLOYMENT_NAME_STORAGE=${OPTARG};;
    r) REGION=${OPTARG};;
    i) SCANNER_INFO_JSON=${OPTARG};;
    u) PACKAGE_URL=${OPTARG};;
    k) REPORT_OBJECT_KEY=${OPTARG};;
    m) MANAGEMENT_SERVICE_ACCOUNT=${OPTARG};;
  esac
done

while IFS== read key value
do
  printf -v "$key" "$value"
done < <(echo $SCANNER_INFO_JSON | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]')

GCP_PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2> /dev/null)
ARTIFACT_BUCKET_NAME='fss-artifact'-$(cat /proc/sys/kernel/random/uuid || uuidgen | tr '[:upper:]' '[:lower:]')

echo "Scanning bucket name: $SCANNING_BUCKET_NAME";
echo "Artifact bucket name: $ARTIFACT_BUCKET_NAME";
echo "Scanner info JSON: $SCANNER_INFO_JSON"
echo "Storage Deployment Name: $DEPLOYMENT_NAME_STORAGE";
echo "GCP Project ID: $GCP_PROJECT_ID";
echo "Region: $REGION";
echo "Package URL: $PACKAGE_URL";
echo "Report Object Key: $REPORT_OBJECT_KEY";
echo "Management Service Account: $MANAGEMENT_SERVICE_ACCOUNT";

echo "Will deploy file storage security protection unit storage stack, Ctrl-C to cancel..."
sleep 5

if [ -z "$PACKAGE_URL" ]; then
  PACKAGE_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
fi

if [ -z "$REPORT_OBJECT_KEY" ]; then
  REPORT_OBJECT_KEY='False'
fi

TEMPLATES_FILE='gcp-templates.zip'
LISTENER_FILE='gcp-listener.zip'
ACTION_TAG_FILE='gcp-action-tag.zip'

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

prepareArtifact $LISTENER_FILE
prepareArtifact $ACTION_TAG_FILE

# Deploy or update File Storage Security roles
echo "Deploying File Storage Security roles..."
FSS_ROLES_DEPLOYMENT='file-storage-security-roles'
([[ "DONE" == $(gcloud deployment-manager deployments describe $FSS_ROLES_DEPLOYMENT --format json | jq -r '.deployment.operation.status') ]] \
  && gcloud deployment-manager deployments update $FSS_ROLES_DEPLOYMENT --config templates/fss-roles.yaml) \
  || gcloud deployment-manager deployments create $FSS_ROLES_DEPLOYMENT --config templates/fss-roles.yaml

sed -i.bak "s/<REGION>/$REGION/g" templates/storage.yaml
sed -i.bak "s/<ARTIFACT_BUCKET_NAME>/$ARTIFACT_BUCKET_NAME/g" templates/storage.yaml
sed -i.bak "s/<SCANNING_BUCKET_NAME>/$SCANNING_BUCKET_NAME/g" templates/storage.yaml
sed -i.bak "s/<SCANNER_TOPIC>/$SCANNER_TOPIC/g" templates/storage.yaml
sed -i.bak "s/<SCANNER_PROJECT_ID>/$SCANNER_PROJECT_ID/g" templates/storage.yaml
sed -i.bak "s/<SCANNER_SERVICE_ACCOUNT_ID>/$SCANNER_SERVICE_ACCOUNT_ID/g" templates/storage.yaml
sed -i.bak "s/<DEPLOYMENT_NAME>/$DEPLOYMENT_NAME_STORAGE/g" templates/storage.yaml
sed -i.bak "s/<REPORT_OBJECT_KEY>/$REPORT_OBJECT_KEY/g" templates/storage.yaml
sed -i.bak "s/<MANAGEMENT_SERVICE_ACCOUNT_ID>/$MANAGEMENT_SERVICE_ACCOUNT/g" templates/storage.yaml
cat templates/storage.yaml

# Create storage stack
gcloud deployment-manager deployments create $DEPLOYMENT_NAME_STORAGE --config templates/storage.yaml

STORAGE_DEPLOYMENT=$(gcloud deployment-manager deployments describe $DEPLOYMENT_NAME_STORAGE --format "json")

searchStorageJSONOutputs() {
  echo $STORAGE_DEPLOYMENT | jq -r --arg v "$1" '.outputs[] | select(.name==$v).finalValue'
}

STORAGE_PROJECT_ID=$(searchStorageJSONOutputs storageProjectID)
BUCKET_LISTENER_SERVICE_ACCOUNT_ID=$(searchStorageJSONOutputs bucketListenerServiceAccountID)
SCAN_RESULT_TOPIC=$(searchStorageJSONOutputs scanResultTopic)

# Binding service account and role on Pub/Sub Topics.
# TODO Can be removed after backend API is ready
gcloud pubsub topics add-iam-policy-binding $SCANNER_TOPIC --member="serviceAccount:$BUCKET_LISTENER_SERVICE_ACCOUNT_ID@$STORAGE_PROJECT_ID.iam.gserviceaccount.com" --role='roles/pubsub.publisher'

# Remove the artifact bucket
gsutil rm -r gs://$ARTIFACT_BUCKET_NAME
rm -rf templates

printStorageJSON() {
  STORAGE_JSON=$(jq --null-input \
    --arg projectID "$STORAGE_PROJECT_ID" \
    --arg deploymentName "$DEPLOYMENT_NAME_STORAGE" \
    '{"projectID": $projectID, "deploymentName": $deploymentName}')
  echo $STORAGE_JSON > $DEPLOYMENT_NAME_STORAGE.json
  cat $DEPLOYMENT_NAME_STORAGE.json
}

echo "FSS Protection Unit Information:"
printStorageJSON
