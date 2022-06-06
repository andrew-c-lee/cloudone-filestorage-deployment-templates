#!/bin/bash
set -e

while getopts s:d:r:u: args
do
  case "${args}" in
    s) SCANNING_BUCKET_NAME=${OPTARG};;
    d) DEPLOYMENT_NAME_PREFIX=${OPTARG};;
    r) REGION=${OPTARG};;
    u) PACKAGE_URL=${OPTARG};;
  esac
done

DEPLOYMENT_NAME_SCANNER=$DEPLOYMENT_NAME_PREFIX'-scanner'
DEPLOYMENT_NAME_STORAGE=$DEPLOYMENT_NAME_PREFIX'-storage'

if [ -z "$PACKAGE_URL" ]; then
  bash deployment-script-scanner.sh -d $DEPLOYMENT_NAME_SCANNER -r $REGION
  bash deployment-script-storage.sh -s $SCANNING_BUCKET_NAME -d $DEPLOYMENT_NAME_STORAGE -r $REGION -i "$(cat $DEPLOYMENT_NAME_SCANNER-info.json)"
else
  bash deployment-script-scanner.sh -d $DEPLOYMENT_NAME_SCANNER -r $REGION -u $PACKAGE_URL
  bash deployment-script-storage.sh -s $SCANNING_BUCKET_NAME -d $DEPLOYMENT_NAME_STORAGE -r $REGION -i "$(cat $DEPLOYMENT_NAME_SCANNER-info.json)" -u $PACKAGE_URL
fi
