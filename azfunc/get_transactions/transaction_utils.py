from tfsoffice import Client
import pandas as pd
import logging

import sys
import os

#sys.path.append(os.path.abspath("")) # Hack for local development
sys.path.append('/home/site/wwwroot') # Hack for remote

from shared_code.shared_utils import *

table_schema = {
 'Date': 'object',
 'AccountNo': 'Int64',
 'Currency': 'string',
 'CurrencyRate': 'float',
 'CurrencyUnit': 'Int64',
 'Amount': 'float',
 'StampNo': 'Int64',
 'Period': 'object',
 'TransactionTypeId': 'Int64',
 'Comment': 'string',
 'TransactionNo': 'Int64',
 'VatCode': 'Int64',
 'Id': 'string',
 'LinkId': 'Int64',
 'InvoiceNo': 'string',
 'SequenceNo': 'Int64',
 'SystemType': 'string',
 'DueDate': 'object',
 'RegistrationDate': 'object',
 'DateChanged': 'object',
 'Hidden': 'bool',
 'Open': 'bool',
 'OCR': 'string',
 'VatDividend': 'float',
 'HasVatDividend': 'bool',
 'Type': 'string',
 'Name': 'string',
 'Value': 'string',
 'Percent': 'float',
 'TypeId': 'Int64'
}

def get_transactions_method(api, **kwargs):
    return api.transactions.get_transactions(**kwargs)

def separate_transaction_dims(results, table_schema, record_path=['Dimensions', 'Dimension'], meta=['Id', 'ClientName']):
    dims_df = (pd.json_normalize(results, record_path, meta)
                .set_index(meta+['Type'])
                .unstack())
    for col in dims_df:
        dims_df[col] = dims_df[col].astype(table_schema[col[0]])
    dims_df.columns = dims_df.columns.get_level_values(1) + dims_df.columns.get_level_values(0)
    return dims_df    

def get_all_transactions(username:str, password:str, apikey:str, table_schema:dict, retries:int=3, **kwargs):
    
    api = Client(username, password, apikey)
    
    identities = api.authenticate.get_identities()
    identity_tuples = [(i, x['Id'], x['Client']['Name']) for i, x in enumerate(identities['results'])]
    
    list_of_dicts = []
    
    for tup in identity_tuples:
        client_dict = retry_get(username, password, apikey, tup[1], get_transactions_method, **kwargs)
        if client_dict['count']==0:
            continue
        client_dict = add_client_name(client_dict, tup[2])
        list_of_dicts.append(client_dict)
    
    output_dict = combine_dicts(list_of_dicts)
    
    if output_dict['count']==0:
        return None
    
    dimension_data = True

    try:
        dims_df = separate_transaction_dims(output_dict['results'], table_schema)
    except KeyError:
        list_of_keys = []
        dim_count = 0
        for el in output_dict['results']:
            list_of_keys.extend(el.keys())
            dim_count += len(el['Dimensions'])
        if dim_count==0:
            logging.info("No rows contain dimension data. Continuing to write to destination table")
            dimension_data = False
        else:
            message = "Unexpected error occurred. Keys not found in source"
            keys = ['Id', 'ClientName', 'Type']
            missing = [x for x in keys if x not in list_of_keys]
            error = "The following keys are missing {}".format(missing)
            return {'message':message, 'error':error}
    
    trans_df = pd.json_normalize(output_dict['results'])
    
    if dimension_data:
        trans_df = trans_df.merge(dims_df, how = 'left', left_on = ['ClientName', 'Id'], right_index = True)
                    
    trans_df = trans_df.drop(['Dimensions', 'Dimensions.Dimension'], axis = 1, errors = 'ignore')

    trans_df = convert_types(trans_df, table_schema)
    trans_df.columns = map(camel_to_uppercase_snake, trans_df.columns)
    
    return trans_df