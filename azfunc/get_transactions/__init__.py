import sys
import os
#sys.path.append(os.path.abspath("")) # Hack for local development
sys.path.append('/home/site/wwwroot') # Hack for remote

import logging
import azure.functions as func
from shared_code.shared_utils import set_param, create_sqlalchemy_engine, truncate_and_write_table
from get_transactions.transaction_utils import *

from tfsoffice import Client
import pandas as pd
import numpy as np
import re
import json

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    api_username_alias='API_UID'
    api_password_alias='API_PWD'
    api_key_alias='API_KEY'
    start_date_alias='SEARCH_START_DATE'
    end_date_alias ='SEARCH_END_DATE'
    sql_server_name_alias='SQL_SERVER_NAME'
    sql_db_name_alias='SQL_DB_NAME'
    sql_db_username_alias='SQL_DB_UID'
    sql_db_password_alias='SQL_DB_PWD'

    api_username = set_param(req, api_username_alias)
    api_password = set_param(req, api_password_alias)
    api_key = set_param(req, api_key_alias)
    sql_server_name=set_param(req, sql_server_name_alias)
    sql_db_name=set_param(req, sql_db_name_alias)
    sql_db_username=set_param(req, sql_db_username_alias)
    sql_db_password=set_param(req, sql_db_password_alias)
    start_date=set_param(req, start_date_alias)
    end_date=set_param(req, end_date_alias)

    logging.info('Processing main function...')
    df = get_all_transactions(api_username, api_password, api_key, date_start=start_date,
                            date_end=end_date,table_schema=table_schema)

    dest_transaction_table = 'RAW_24SO_TRANSACTION'

    if df is None:
        return func.HttpResponse(json.dumps({
            "row_count": 0,
            "destintaion_table": dest_transaction_table,
            "message":"The search criteria matches no rows from source"
            }
            ), mimetype="application/json"
            )

    if isinstance(df, dict):
        return func.HttpResponse(json.dumps(df),mimetype="application/json")

    engine = create_sqlalchemy_engine(sql_server_name, sql_db_name, sql_db_username, sql_db_password)

    count = truncate_and_write_table(dest_transaction_table, engine, df)

    return func.HttpResponse(json.dumps({"row_count":count,
                                         "destination_table":dest_transaction_table}),mimetype="application/json")