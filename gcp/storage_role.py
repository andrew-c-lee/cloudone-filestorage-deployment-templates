# Copyright (C) 2022 Trend Micro Inc. All rights reserved.
import common

def create_storage_role_resources(context):
    bl_role_id, pat_role_id = '', ''
    prefix = common.get_prefix(context, 'storage')
    if context.properties['action'] == 'update':
        bl_role_id = context.properties['blRoleID']
        pat_role_id = context.properties['patRoleID']
    else:
        role_suffix = context.env['current_time']
        bl_role_id = f'{prefix.lower().replace("-","_")}_bl_role_{role_suffix}'
        pat_role_id = f'{prefix.lower().replace("-","_")}_pat_role_{role_suffix}'

    bucket_listener_role = {
        'name': f'{prefix}-bucket-listener-role',
        'type': 'gcp-types/iam-v1:projects.roles',
        'properties': {
            'parent': f'projects/{context.env["project"]}',
            'roleId': bl_role_id,
            'role':{
                'title': f'{prefix.lower()}-bucket-listener-role',
                'description': 'Storage stack bucket listener role',
                'stage': 'GA',
                'includedPermissions': [
                    'iam.serviceAccounts.signBlob'
                ]
            }
        }
    }

    post_action_tag_role = {
        'name': f'{prefix}-post-action-tag-role',
        'type': 'gcp-types/iam-v1:projects.roles',
        'properties': {
            'parent': f'projects/{context.env["project"]}',
            'roleId': pat_role_id,
            'role':{
                'title': f'{prefix.lower()}-post-action-tag-role',
                'description': 'Storage stack post action tag role',
                'stage': 'GA',
                'includedPermissions': [
                    'storage.objects.get',
                    'storage.objects.update'
                ]
            }
        }
    }

    resources = [
        bucket_listener_role,
        post_action_tag_role
    ]
    outputs = [{
        'name':  'bucketListenerRoleID',
        'value': bucket_listener_role["properties"]["roleId"]
    },{
        'name':  'postActionTagRoleID',
        'value': post_action_tag_role["properties"]["roleId"]
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_storage_role_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
