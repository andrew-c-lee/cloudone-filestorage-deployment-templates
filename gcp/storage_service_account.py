# Copyright (C) 2022 Trend Micro Inc. All rights reserved.
import common

def create_storage_service_account_resources(context):
    prefix = common.get_prefix(context, 'storage')

    bucket_listener_service_account = {
        'name': f'{prefix}-bucket-listener-service-account',
        'type': 'gcp-types/iam-v1:projects.serviceAccounts',
        'properties': {
            # bucket-listener-service-account
            'accountId': f'{prefix.lower()}-bl-sa',
            'displayName': 'Service Account for Bucket Listener Cloud Function',
        }
    }

    binding_bucket_listener_role = {
        'name': 'bind-bucket-listener-iam-policy',
        'type': 'gcp-types/cloudresourcemanager-v1:virtual.projects.iamMemberBinding',
        'properties': {
            'resource': context.env['project'],
            'role': f"projects/{context.env['project']}/roles/{context.properties['bucketListenerRoleID']}",
            'member': f'serviceAccount:{bucket_listener_service_account["properties"]["accountId"]}@{context.env["project"]}.iam.gserviceaccount.com'
        },
        'metadata': {
            'dependsOn': [bucket_listener_service_account['name']]
        }
    }

    post_action_tag_service_account = {
        'name': f'{context.env["deployment"]}-post-action-tag-service-account',
        'type': 'gcp-types/iam-v1:projects.serviceAccounts',
        'properties': {
            'accountId': f'{prefix.lower()}-pat-sa',
            'displayName': 'Service Account for PostAction Tag Cloud Function',
        }
    }

    resources = [
        bucket_listener_service_account,
        binding_bucket_listener_role,
        post_action_tag_service_account
    ]
    outputs = [{
        'name':  'bucketListenerServiceAccountID',
        'value': bucket_listener_service_account['properties']['accountId']
    },{
        'name':  'postActionTagServiceAccountID',
        'value': post_action_tag_service_account['properties']['accountId']
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_storage_service_account_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
