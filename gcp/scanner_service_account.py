# Copyright (C) 2022 Trend Micro Inc. All rights reserved.
import common

def create_scanner_service_account_resources(context):
    prefix = common.get_prefix(context, 'scanner')

    scanner_service_account = {
        'name': f'{prefix}-scanner-service-account',
        'type': 'gcp-types/iam-v1:projects.serviceAccounts',
        'properties': {
            'accountId': f'{prefix.lower()}-scan-sa',
            'displayName': 'Service Account for Scanner Cloud Function'
        }
    }

    resources = [
        scanner_service_account
    ]
    outputs = [{
        'name':  'scannerServiceAccountID',
        'value': scanner_service_account['properties']['accountId']
    },{
        'name': 'scannerProjectID',
        'value': context.env['project']
    }]
    return (resources, outputs)


def generate_config(context):
    """ Entry point for the deployment resources. """

    resources, outputs = create_scanner_service_account_resources(context)

    return {
        'resources': resources,
        'outputs': outputs
    }
