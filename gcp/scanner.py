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
                'LICENSE': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJ3d3cudHJlbmRtaWNyby5jb20iLCJleHAiOjE2NTc4NDMyMDAsIm5iZiI6MTY0NTU4NzIyMiwiaWF0IjoxNjQ1NTg3MjIyLCJzdWIiOiJnY3AtcHJldmlldy1saWNlbnNlIiwiY2xvdWRPbmUiOnsiYWNjb3VudCI6IjU2NDUwNTA5NDE4NyJ9fQ.VBO3uXfXAx3B7wrbQL1KnB60TD4HEbKIJKD7Faohpgyuo2-3nNyYrUyTep7Bee0p2ElZ1BYf_z7_PeVGldLUZeue1FOkNYOuoBdVxeIN5aZ8ayvqY0FJ22CMIOcqbMv-tkXPyPP51tVp5prfFMOOnOKSVRLq5-uRrjxo1tvz2wuaos41Z1FbxoBMx7NFlVA1F9bkDGil2nazVb2IJ4LTDUDIDVEvM5-rx1Y8y3wtu4sEPR9gVRKhxONT2B8gsgZipFbdZ9REGM2gaeZ_78FfcxDEfqu1ty3EwhfUp9k8ibi9p637JTqJp09dcM7CyXRsij_v2b68m9zw3sdoZX5dBTXGvB4T-KSXsZHE_T-ECd5k0h3FZFR9zwE7lKlQznw1qjklZYnaY0BGazHdNCXX37AqB0UFvo7LHnQGwFTvmOMmlrOrlUn2s-8BcM6TMp9-uxCBmiDrsYrH7A1Uoewk6GB1x02p2tKbMCpSVdZAXl8kyOW2sIyqXVvMy7rvo2GysLOXmHvf6R0uvhgRWYKN0GcNpBGKnpeil90HVGPjmRW8ZVjjvX0EnmAw73zrYuXFnj0aKf4rrkLvPY779qF5Exm_mvyWaUjEDEDNwd_qOAUv3dEXqkDOeY3tXp5fHZGBFfjSCmUlAg3KUvcSc-FCt9a8cCHo5xo-x1NMHuwHuuI',
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
