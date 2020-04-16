from tfsoffice import Client
import pandas as pd
import numpy as np
import re
import azure.functions as func
import logging

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