import sys
import os
#sys.path.append(os.path.abspath(""))
sys.path.append('/home/site/wwwroot')

import logging
import azure.functions as func
from shared_code.shared_utils import set_param
from get_transactions.transaction_utils import *

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
    start_date_alias='START_DATE'
    end_date_alias ='END_DATE'
    account_name_alias='BLOB_ACCOUNT_NAME'
    account_key_alias='BLOB_ACCOUNT_KEY'

    api_username = set_param(req, api_username_alias)
    api_password = set_param(req, api_password_alias)
    api_key = set_param(req, api_key_alias)
    account_name=set_param(req, account_name_alias)
    account_key=set_param(req, account_key_alias)
    start_date=set_param(req, start_date_alias)
    end_date=set_param(req, end_date_alias)

    blobService = BlockBlobService(account_name=account_name, account_key=account_key)

    logging.info('Processing main function...')
    df = get_all_transactions(api_username, api_password, api_key, date_start=start_date,
                            date_end=end_date,table_schema=table_schema)

    if df is None:
        return func.HttpResponse(json.dumps({"message":"The search criteria matches no rows from source"}),mimetype="application/json")

    containerName='functions'
    index=None
    encoding='utf-8'
    sep='|'

    if isinstance(df, dict):
        return func.HttpResponse(json.dumps(df),mimetype="application/json")

    dest_transaction_table = '24SO_Transaction'
    blobService.create_blob_from_text(containerName, '{}.csv'.format(dest_transaction_table), df.to_csv(index=index,encoding = encoding, sep=sep))
    logging.info('Transaction data written to blob')

    if len(df)>0:
        return func.HttpResponse(json.dumps({"message":"{} rows written to {}".format(len(df), dest_transaction_table)}),mimetype="application/json")
    else:
        return func.HttpResponse(
             json.dumps({"message":"Please pass a name on the query string or in the request body"}),mimetype="application/json",
             status_code=400
        )