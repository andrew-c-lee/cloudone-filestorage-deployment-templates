# Cloud One File Storage Security Deploy Scanner Stack and Storage Stack

## Overview

<walkthrough-tutorial-duration duration="10"></walkthrough-tutorial-duration>

This tutorial will guide you to protect an existing GCP bucket from malware by deploying Cloud One File Storage Security scanner stack and storage.

There is also a [video demonstration](https://www.youtube.com/watch?v) if you prefer.

--------------------------------

**This feature is part of a controlled release and is in Preview. Content on this page is subject to change.**

### Permissions

For the list of permissions that File Storage Security management roles will have after it has been deployed and configured:

* Search on "ManagementRole" in the <walkthrough-editor-open-file filePath="scanner.yaml">scanner stack template</walkthrough-editor-open-file>
* Search on "ManagementRole" in the <walkthrough-editor-open-file filePath="storage.yaml">storage stack template</walkthrough-editor-open-file>

### Backend updates

For automatic backend updates that will be pushed, see [Update components](https://cloudone.trendmicro.com/docs/file-storage-security/).

## Project Setup

Copy the execute the script below to select the project where the bucket you want to scan is located. The scanner and storage stacks will be deployed in the same project.

<walkthrough-project-setup></walkthrough-project-setup>

```sh
gcloud config set project <walkthrough-project-id/>
```

## Configure and Deploy the Stacks

Specify the following fields and execute the deployment script in cloud shell:

1. Stack name: Specify the prefix of this deployment. Please keep it under 22 characters.
2. Scanning bucket name: Specify the existing bucket name that you wish to protect.
3. Region: Specify the region of your bucket. For the list of supported GCP region, please see [Supported GCP Regions](https://cloudone.trendmicro.com/docs/file-storage-security/).
4. Service account: Copy and paste the service account information for the File Storage Security console.

```sh
./deployment-script.sh -d <STACK_NAME> -s <SCANNING_BUCKET_NAME> -r <REGION> -m <SERVICE_ACCOUNT>
```

## Configure JSON in File Storage Security console

To complete the deployment process, once the stacks are deployed, follow the steps to configure management role:

1. Select the Explorer tab in GCP Cloud Shell Editor
2. Copy the scanner-storage.json file
3. Paste the JSON file back to the File Storage Security console.

--------------------------------

Deployment Status
To find out the status of your deployment, go to [Deployment Manager](https://console.cloud.google.com/dm) and search for:

* <STACK_NAME>-scanner
* <STACK_NAME>-storage

## Start scanning

You have now deployed File Storage Security scanner and storage stacks successfully. To test your deployment, you'll need to generate a malware detection using the eicar file.

Follow the instructions below. There is also a [video demonstration](https://www.youtube.com/watch?v) if you prefer.

1. Obtain the eicar file:
    a. Temporarily disable your virus scanner, otherwise it will catch the eicar file and delete it.
    1. Go to the [eicar file page](https://www.eicar.org/?page_id=3950).
    2. Download eicar_com.zip or any of the other versions of this file.
    3. Check the ZIP file to make sure it includes a file.
2. Add the eicar file to the protected bucket. File Storage Security scans the file and detects malware.
3. Examine the tags from the scan result:
    1. In your bucket, select eicar_com.zip, then select Edit Metadata.
    2. Look for the following tags:
        1. fss-scan-date: date_and_time
        2. fss-scan-result: malicious
        3. fss-scanned: true

The tags indicate that File Storage Security scanned the file and tagged it correctly as malware. The scan results are also available in the console on the Scan Activity page.

**Remember to re-enable your virus scanner after testing is complete.**

--------------------------------

### Next Step

[Quarantine or promote files based on the scan result](https://cloudone.trendmicro.com/docs/file-storage-security/)
