from tfsoffice import Client
import pandas as pd
import numpy as np
import re
import azure.functions as func
import logging
import urllib
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine

def set_param(req, alias):
    par = req.params.get(alias)
    if not par:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            par = req_body.get(alias)
    if not par:
        return func.HttpResponse(
            "Please pass a value for {} in the query string".format(par),
            status_code=400
    )
    return(par)

def add_client_name(d:dict, client_name:str):
    for subd in d['results']:
        subd['ClientName'] = client_name
    return(d)

def login_and_set_identity(username:str, password:str, apikey:str, identity:str):
    api = Client(username, password, apikey)
    api.authenticate.set_identity_by_id(identity)
    return api

def retry_get(username, password, apikey, identity,  api_operation, retries=3, **kwargs):
    for index in range(0, retries):
            try:
                api = login_and_set_identity(username, password, apikey, identity)
                client_dict = api_operation(api, **kwargs)
            except:
                logging.info("HTTP request attempt {} failed")
                if index+1!=retries:
                    logging.info("Retrying...")
                    continue
                raise
            break
    return client_dict

def combine_dicts(list_of_dicts):
    output_dict = {'count':0,'results':[]}
    for d in list_of_dicts:
        output_dict['count'] += d['count']
        output_dict['results'].extend(d['results'])
    return output_dict

def convert_types(df, table_schema):
    for col in [x for x in df if x in table_schema.keys()]:
        df[col] = df[col].astype(table_schema[col])
        if 'Date' in col:
            df[col] = pd.to_datetime(df[col], utc=True).dt.tz_localize(None).astype(np.datetime64)
    return df

def camel_to_uppercase_snake(name):
  name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
  return re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).upper()

def create_sqlalchemy_engine(server, database, db_username, db_password, driver='{ODBC Driver 17 for SQL Server}', port='1433'):
    server_string = server + '.database.windows.net,' + port
    params = urllib.parse.quote_plus \
    (r'Driver={};Server=tcp:{};Database={};Uid={};Pwd={};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;'
    .format(driver, server_string, database, db_username, db_password))
    conn_str = 'mssql+pyodbc:///?odbc_connect={}'.format(params)
    engine = create_engine(conn_str,echo=True, fast_executemany=True)
    return engine

def truncate_and_write_table(table_name, engine, df=None):
    Session = sessionmaker(engine)
    session = Session()

    select_query = 'SELECT COUNT(*) FROM {}'.format(table_name)
    truncate_query = 'TRUNCATE TABLE {}'.format(table_name)

    pre_count = session.execute(select_query).scalar()
    session.execute(truncate_query)
    session.commit()
    assert session.execute(select_query).scalar() == 0
    logging.info('Deleted all {} rows from {}'.format(pre_count, table_name))

    if df is not None:
        df.to_sql(table_name, con = engine, if_exists = 'append', index = False)

    post_count = session.execute(select_query).scalar()
    session.close()
    
    logging.info('{} rows written to {}'.format(post_count, table_name))

    return post_count