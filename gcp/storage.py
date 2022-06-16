# Copyright (C) 2022 Trend Micro Inc. All rights reserved.
import common


def create_storage_stack_resources(context):
    prefix = common.get_prefix(context, 'storage')

    scan_result_topic = {
        'name': f'{prefix}-scan-result-topic',
        'type': 'pubsub.py',
        'properties': {
            'name': f'{prefix}-scan-result-topic'
        }
    }

    bucket_listener = {
        'name': f'{prefix}-bucket-listener',
        'type': 'cloud_function.py',
        'properties': {
            'region': context.properties["region"],
            'entryPoint': 'handler',
            'sourceArchiveUrl': f'gs://{context.properties["artifactBucket"]}/gcp-listener.zip',
            'serviceAccountEmail': f'{context.properties["bucketListenerServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com',
            'runtime': 'nodejs16',
            'triggerStorage': {
                'bucketName': context.properties['scanningBucket'],
                'event': 'finalize',
            },
            'environmentVariables': {
                'SCANNER_PUBSUB_TOPIC': context.properties['scannerTopic'],
                'SCANNER_PROJECT_ID': context.properties['scannerProjectID'],
                'SCAN_RESULT_TOPIC': f'projects/{context.env["project"]}/topics/{scan_result_topic["name"]}',
                'DEPLOYMENT_NAME': context.properties['deploymentName'],
                'REPORT_OBJECT_KEY': context.properties['reportObjectKey']
            },
            'retryOnFailure': True,
        }
    }

    bucket_listener_service_account_binding = {
        'name': 'bucket-listener-service-account-binding',
        'type': 'gcp-types/storage-v1:virtual.buckets.iamMemberBinding',
        'properties': {
            'bucket': context.properties['scanningBucket'],
            'role': "roles/storage.legacyObjectReader",
            'member': f'serviceAccount:{context.properties["bucketListenerServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com'
        }
    }

    post_scan_action = {
        'name': f'{prefix}-post-action-tag',
        'type': 'cloud_function.py',
        'properties': {
            'region': context.properties["region"],
            'entryPoint': 'main',
            'sourceArchiveUrl': f'gs://{context.properties["artifactBucket"]}/gcp-action-tag.zip',
            'serviceAccountEmail': f'{context.properties["postActionTagServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com',
            'runtime': 'python38',
            'triggerTopic': scan_result_topic['name'],
            'retryOnFailure': True,
        },
        'metadata': {
            'dependsOn': [scan_result_topic['name']]
        }
    }

    post_scan_action_service_account_binding = {
        'name': 'post-scan-action-service-account-binding',
        'type': 'gcp-types/storage-v1:virtual.buckets.iamMemberBinding',
        'properties': {
            'bucket': context.properties['scanningBucket'],
            'role': f"projects/{context.env['project']}/roles/{context.properties['postActionTagRoleID']}",
            'member': f'serviceAccount:{context.properties["postActionTagServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com'
        }
    }

    resources = [
        bucket_listener,
        bucket_listener_service_account_binding,
        post_scan_action,
        post_scan_action_service_account_binding,
        scan_result_topic,
    ]
    outputs = [{
        'name': 'storageProjectID',
        'value': context.env['project']
    },{
        'name': 'bucketListenerSourceArchiveUrl',
        'value': f'$(ref.{bucket_listener["name"]}.sourceArchiveUrl)'
    },{
        'name': 'scanResultTopic',
        'value': scan_result_topic["name"]
    },{
        'name': 'bucketListenerFunctionName',
        'value': '$(ref.{}.name)'.format(bucket_listener['name'])
    },{
        'name': 'postScanActionTagFunctionName',
        'value': '$(ref.{}.name)'.format(post_scan_action['name'])
    },{
        'name': 'region',
        'value': context.properties['region']
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_storage_stack_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
