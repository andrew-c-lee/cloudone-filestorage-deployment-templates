# Copyright (C) 2022 Trend Micro Inc. All rights reserved.
import common

def create_scanner_stack_resources(context):
    prefix = common.get_prefix(context, 'scanner')

    scanner_topic = {
        'name': f'{prefix}-scanner-topic',
        'type': 'pubsub.py',
        'properties': {
            'name': f'{prefix}-scanner-topic'
        }
    }

    scanner = {
        'name': f'{prefix}-scanner',
        'type': 'cloud_function.py',
        'properties': {
            'region': context.properties['region'],
            'sourceArchiveUrl': f'gs://{context.properties["artifactBucket"]}/gcp-scanner.zip',
            'entryPoint': 'main',
            'serviceAccountEmail': f'{context.properties["scannerServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com',
            'runtime': 'python38',
            'availableMemoryMb': 2048,
            'timeout': '120s',
            'triggerTopic': scanner_topic['name'],
            'environmentVariables': {
                'LD_LIBRARY_PATH': '/workspace:/workspace/lib',
                'PATTERN_PATH': './patterns',
                'PROJECT_ID': context.env['project'],
                'SUBJECT': 'gcp-preview-license',
                'DEPLOYMENT_NAME': context.properties['deploymentName']
            },
            'secretEnvironmentVariables': [
                {
                    'key': 'SCANNER_SECRETS',
                    'projectId': context.env['project'],
                    'secret': f'{context.properties["scannerSecretsName"]}',
                    'version': 'latest'
                }
            ],
            'retryOnFailure': True,
        },
        'metadata': {
            'dependsOn': [scanner_topic['name']]
        }
    }

    scanner_topic_dlt = {
        'name': f'{prefix}-scanner-topic-dlt',
        'type': 'pubsub.py',
        'properties': {
            'name': f'{prefix}-scanner-topic-dlt'
        }
    }

    scanner_dlt = {
        'name': f'{prefix}-scanner-dlt',
        'type': 'cloud_function.py',
        'properties': {
            'region': context.properties["region"],
            'sourceArchiveUrl': f'gs://{context.properties["artifactBucket"]}/gcp-scanner-dlt.zip',
            'entryPoint': 'main',
            'serviceAccountEmail': f'{context.properties["scannerServiceAccountID"]}@{context.env["project"]}.iam.gserviceaccount.com',
            'runtime': 'python38',
            'triggerTopic': scanner_topic_dlt['name'],
            'environmentVariables': {}
        },
        'metadata': {
            'dependsOn': [scanner_topic_dlt['name']]
        }
    }

    resources = [
        scanner,
        scanner_dlt,
        scanner_topic,
        scanner_topic_dlt
    ]
    outputs = [{
        'name': 'scannerTopic',
        'value': scanner_topic['name']
    },{
        'name': 'scannerTopicDLT',
        'value': scanner_topic_dlt['name']
    },{
        'name': 'scannerProjectID',
        'value': context.env['project']
    },{
        'name': 'scannerFunctionName',
        'value': '$(ref.{}.name)'.format(scanner['name'])
    },{
        'name': 'scannerDLTFunctionName',
        'value': '$(ref.{}.name)'.format(scanner_dlt['name'])
    },{
        'name': 'region',
        'value': context.properties["region"]
    },{
        'name': 'scannerSecretsName',
        'value': context.properties["scannerSecretsName"]
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_scanner_stack_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
