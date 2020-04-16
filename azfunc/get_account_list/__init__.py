import sys
import os
#sys.path.append(os.path.abspath("")) # Hack for local development
sys.path.append('/home/site/wwwroot') # Hack for remote

import logging
import azure.functions as func
from shared_code.shared_utils import set_param
from get_account_list.account_utils import *

from tfsoffice import Client
import pandas as pd
import numpy as np
import re
from azure.storage.blob import BlockBlobService
import json

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    api_username_alias='UID'
    api_password_alias='PWD'
    api_key_alias='KEY'
    account_name_alias='BLOB_ACCOUNT_NAME'
    account_key_alias='BLOB_ACCOUNT_KEY'

    api_username = set_param(req, api_username_alias)
    api_password = set_param(req, api_password_alias)
    api_key = set_param(req, api_key_alias)
    account_name=set_param(req, account_name_alias)
    account_key=set_param(req, account_key_alias)

    blobService = BlockBlobService(account_name=account_name, account_key=account_key)

    logging.info('Processing main function...')
    df = get_all_account_lists(api_username, api_password, api_key, table_schema=table_schema)

    if df is None:
        return func.HttpResponse(json.dumps({"message":"The search criteria matches no rows from source"}),mimetype="application/json")

    containerName='functions'
    index=None
    encoding='utf-8'
    sep='|'

    dest_account_table = '24SO_Account'
    blobService.create_blob_from_text(containerName, '{}.csv'.format(dest_account_table), df.to_csv(index=index,encoding = encoding, sep=sep))
    logging.info('Account data written to blob')

    if len(df)>0:
        return func.HttpResponse(json.dumps({"message":"{} rows written to {}".format(len(df), dest_account_table)}),mimetype="application/json")
    else:
        return func.HttpResponse(
             json.dumps({"message":"Please pass a name on the query string or in the request body"}),mimetype="application/json",
             status_code=400
        )