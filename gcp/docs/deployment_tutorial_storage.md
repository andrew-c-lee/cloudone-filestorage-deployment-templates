# Cloud One File Storage Security

# Deploy storage stack

## Overview

<walkthrough-tutorial-duration duration="5"></walkthrough-tutorial-duration>

This tutorial will guide you to deploy the Cloud One File Storage Security storage stack.

--------------------------------

### Permissions

The permissions that File Storage Security management roles will have after it has been deployed and configured are defined in:

* <walkthrough-editor-open-file filePath="templates/management_roles.py">Management roles</walkthrough-editor-open-file>
* <walkthrough-editor-open-file filePath="templates/storage/storage_stack_roles.py">Storage stack management roles</walkthrough-editor-open-file>

### Backend updates (coming soon)

For automatic backend updates that will be pushed, see [Update components](https://cloudone.trendmicro.com/docs/file-storage-security/component-update-gcp/).

## Project setup

Select the project in which you want to deploy the storage stack, then copy and execute the script in the Cloud Shell:

<walkthrough-project-setup></walkthrough-project-setup>

```sh
gcloud config set project <walkthrough-project-id/>
```

## Configure and deploy the stack

Specify the following fields and execute the deployment script in the Cloud Shell:

1. **Scanning bucket name:** Specify the existing bucket name that you wish to protect.
1. **Deployment name:** Specify the name of this deployment. Please keep it under 22 characters.
1. **Region:** Specify the region of your bucket. For the list of supported GCP regions, please see [Supported GCP Regions](https://cloudone.trendmicro.com/docs/file-storage-security/supported-gcp/#GCPRegion).
1. **Scanner information JSON:** Copy and paste the scanner information from the File Storage Security console.
1. **Service account:** Copy and paste the service account information from the File Storage Security console.

```sh
./deployment-script-storage.sh -s <SCANNING_BUCKET_NAME> -d <DEPLOYMENT_NAME> -r <REGION> -i <SCANNER_INFORMATION> -m <SERVICE_ACCOUNT>
```

## Configure JSON in File Storage Security console

To complete the deployment process, once the stacks are deployed, follow the steps to configure management role:

1. Copy the content of <DEPLOYMENT_NAME>.json from the Cloud Shell script output.
1. Paste the content back to the File Storage Security console - Step 5. Storage Stack

--------------------------------

### Deployment Status

To find out the status of your deployment, go to [Deployment Manager](https://console.cloud.google.com/dm) and search for:

* <DEPLOYMENT_NAME>

## Start scanning

You have now deployed File Storage Security scanner and storage stacks successfully. To test your deployment, you'll need to generate a malware detection using the eicar file.

1. Download the eicar file from eicar file page into your scanning bucket with the script.

    ```sh
    wget https://secure.eicar.org/eicar.com.txt
    gsutil cp eicar.com.txt gs://<SCANNING_BUCKET_NAME>/eicar
    ```

1. File Storage Security scans the file and detects the malware.

1. Execute the script to examine the scan result:

    ```sh
    gsutil stat 'gs://<SCANNING_BUCKET_NAME>/eicar'
    ```

1. In Metadata, look for the following tags:
    * **fss-scan-date**: date_and_time
    * **fss-scan-result**: malicious
    * **fss-scanned**: true

The tags indicate that File Storage Security scanned the file and tagged it correctly as malware. The scan results are also available in the console on the Scan Activity page.

--------------------------------

### Next Step

[Quarantine or promote files based on the scan results](https://cloudone.trendmicro.com/docs/file-storage-security/github-sample-code/#post-scan)
