# Copyright (C) 2022 Trend Micro Inc. All rights reserved.

def create_scanner_role_resources(context):

    scanner_role = {
        'name': f'{context.env["deployment"]}-scanner-role',
        'type': 'gcp-types/iam-v1:projects.roles',
        'properties': {
            'parent': f'projects/{context.env["project"]}',
            'roleId': f'{context.env["deployment"].lower().replace("-","_")}_scanner_role',
            'role':{
                'title': f'{context.env["deployment"].lower()}-scanner-role',
                'description': 'scanner-role',
                'stage': 'GA',
                'includedPermissions': [
                    'pubsub.topics.publish',
                ]
            }
        }
    }

    resources = [
        scanner_role
    ]
    outputs = [{
        'name':  'scannerRoleID',
        'value': scanner_role["properties"]["roleId"]
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_scanner_role_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
