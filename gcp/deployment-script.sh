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

DEPLOYMENT_NAME_SCANNER=$DEPLOYMENT_NAME_PREFIX'-scanner'
DEPLOYMENT_NAME_STORAGE=$DEPLOYMENT_NAME_PREFIX'-storage'

bash deployment-script-scanner.sh -d $DEPLOYMENT_NAME_SCANNER -r $REGION
bash deployment-script-storage.sh -s $SCANNING_BUCKET_NAME -d $DEPLOYMENT_NAME_STORAGE -r $REGION -i "$(cat $DEPLOYMENT_NAME_SCANNER-scanner-info.json)"
