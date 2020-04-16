from tfsoffice import Client
import pandas as pd
import logging

import sys
import os

#sys.path.append(os.path.abspath("")) # Hack for local development
sys.path.append('/home/site/wwwroot') # Hack for remote

from shared_code.shared_utils import *

table_schema = {
 'AccountId': 'Int64',
 'AccountNo': 'Int64',
 'AccountName': 'string',
 'AccountTax': 'Int64',
 'TaxNo': 'Int64',
}

def get_account_list_method(api):
    return api.accounts.get_account_list()   

def get_all_account_lists(username:str, password:str, apikey:str, table_schema:dict, retries:int=3):
    
    api = Client(username, password, apikey)
    
    identities = api.authenticate.get_identities()
    identity_tuples = [(i, x['Id'], x['Client']['Name']) for i, x in enumerate(identities['results'])]
    
    list_of_dicts = []
    
    for tup in identity_tuples:
        client_dict = retry_get(username, password, apikey, tup[1], get_account_list_method)
        if client_dict['count']==0:
            continue
        client_dict = add_client_name(client_dict, tup[2])
        list_of_dicts.append(client_dict)
    
    output_dict = combine_dicts(list_of_dicts)
    
    if output_dict['count']==0:
        return None
    
    account_df = pd.json_normalize(output_dict['results'])

    account_df = convert_types(account_df, table_schema)

    account_df.columns = map(camel_to_uppercase_snake, account_df.columns)
    
    return account_df