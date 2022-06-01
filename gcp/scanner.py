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
                'LICENSE': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJ3d3cudHJlbmRtaWNyby5jb20iLCJleHAiOjE2NjQ3Njk2MDAsIm5iZiI6MTY1NDA1MDU1NCwiaWF0IjoxNjU0MDUwNTU0LCJzdWIiOiJnY3AtcHJldmlldy1saWNlbnNlIiwiY2xvdWRPbmUiOnsiYWNjb3VudCI6IjU2NDUwNTA5NDE4NyJ9fQ.NTRBsm_A6dvG3BQIAZ2tX3IEcBmOD1jlFhf2AwfW_xaQcTnEYdrk5FT0-uG9lQf960j_l5olDWEEwVny7clzm7dhNOi3LqFOoF4h1_oly451u8LMmuj_rmm29hEA_5a4dYBtECkRZK5Pp0xw1chR7DaSz1_DGsLs5kqhdzyoiP3QGGy7vVhnYNHrZLhUNHrILr6ynJoPoSUlAz8szwZ7ZbTK9gMDfXCKVsy2afS0GTbzd4NhLqQf9bDSrNmBhcv3WWxRpSwA90i7V2V7xeOt8TFd22_GNe6uKDlpNYCZSE60f57_E23NgoPfcBAAo_h9r4ErhEEoWSAryWXr_cIpMwvhcNVvFmKNFraIkOP8l58v_2E85qxA_TrmJGd-kLcuoyE1IJVpZHJle6sAZEYyTwUBBxjs_N9nuHqSoO79pJj62VmED9XMsnqY8D8b8v8roazE5YqvPRgN5LqilCMeySQy1jJmmEiwl6k2z1-3SYKefr_j-Q1v_LpUJ9FudlylMLYyK9jUZXXDhO2jkd3zDt3xUybUpyh1CHmh9SYdZoW4yJrcVBvDI82s6quA4fL-akayoRRFHolveNDyUq78JoFwJBHJWMmrOcbAGSMfQfvYQs8Hq9_0ZnSYCIUjr4VxIWr2owWD87S9ISDSNscab03skfijAdEcVlZVIBa5MUo',
                'SUBJECT': 'gcp-preview-license',
            },
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
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_scanner_stack_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
