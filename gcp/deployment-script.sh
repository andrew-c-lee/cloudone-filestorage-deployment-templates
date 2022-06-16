#!/bin/bash
set -e

while getopts s:d:r:u:k:m: args
do
  case "${args}" in
    s) SCANNING_BUCKET_NAME=${OPTARG};;
    d) DEPLOYMENT_NAME_PREFIX=${OPTARG};;
    r) REGION=${OPTARG};;
    u) PACKAGE_URL=${OPTARG};;
    k) REPORT_OBJECT_KEY=${OPTARG};;
    m) MANAGEMENT_SERVICE_ACCOUNT=${OPTARG};;
  esac
done

DEPLOYMENT_NAME_SCANNER=$DEPLOYMENT_NAME_PREFIX'-scanner'
DEPLOYMENT_NAME_STORAGE=$DEPLOYMENT_NAME_PREFIX'-storage'

if [ -z "$PACKAGE_URL" ]; then
  PACKAGE_URL='https://file-storage-security-preview.s3.amazonaws.com/latest/'
fi

if [ -z "$REPORT_OBJECT_KEY" ]; then
  REPORT_OBJECT_KEY='False'
else
  REPORT_OBJECT_KEY=$(echo $REPORT_OBJECT_KEY | tr '[:upper:]' '[:lower:]')
  REPORT_OBJECT_KEY=$(echo ${REPORT_OBJECT_KEY:0:1} | tr '[a-z]' '[A-Z]')${REPORT_OBJECT_KEY:1}
fi

bash deployment-script-scanner.sh -d $DEPLOYMENT_NAME_SCANNER -r $REGION -m $MANAGEMENT_SERVICE_ACCOUNT -u $PACKAGE_URL
bash deployment-script-storage.sh -s $SCANNING_BUCKET_NAME -d $DEPLOYMENT_NAME_STORAGE -r $REGION -m $MANAGEMENT_SERVICE_ACCOUNT -i "$(cat $DEPLOYMENT_NAME_SCANNER-info.json)" -u $PACKAGE_URL -k $REPORT_OBJECT_KEY
