import logging
import azure.functions as func

import pandas as pd
import numpy as np
from azure.storage.blob import BlockBlobService
from tfsoffice import Client
import json

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

trans_dest_dtypes = {'ClientName':'nvarchar',
'Date':'datetime',
'AccountNo':'int',
'Currency':'nvarchar',
'CurrencyRate':'float',
'CurrencyUnit':'int',
'Amount':'float',
'StampNo':'int',
'Period':'int',
'TransactionTypeId':'int',
'Comment':'nvarchar',
'TransactionNo':'int',
'VatCode':'int',
'Id':'nvarchar',
'LinkId':'int',
'InvoiceNo':'nvarchar',
'SequenceNo':'nvarchar',
'SystemType':'nvarchar',
'DueDate':'datetime',
'ProjectType':'nvarchar',
'ProjectName':'nvarchar',
'ProjectPercent':'float',
'ProjectValue':'nvarchar',
'ProjectTypeId':'int',
'DepartmentType':'nvarchar',
'DepartmentName':'nvarchar',
'DepartmentValue':'nvarchar',
'DepartmentPercent':'float',
'DepartmentTypeId':'int',
'EmployeeType':'nvarchar',
'EmployeeName':'nvarchar',
'EmployeeValue':'nvarchar',
'EmployeePercent':'float',
'EmployeeTypeId':'nvarchar',
'ProductValue':'nvarchar',
'ProductPercent':'float',
'ProductTypeId':'int',
'CustomerType':'nvarchar',
'CustomerName':'nvarchar',
'CustomerValue':'nvarchar',
'CustomerPercent':'float',
'CustomerTypeId':'int',
'RegistrationDate':'datetime',
'DateChanged':'datetime',
'Hidden':'nvarchar',
'Open':'nvarchar',
'OCR':'nvarchar',
'HasVatDividend':'nvarchar'}

acc_dest_dtypes={'ClientName':'nvarchar',
'AccountId':'int',
'AccountNo':'int',
'AccountName':'nvarchar',
'AccountTax':'int',
'TaxNo':'int'}

def load_from_24so(username:str, password:str, apikey:str, trans_dest_dtypes:dict, acc_dest_dtypes:dict,blobService, trans:bool=True, account:bool=True, retries:int=3, **kwargs):
    api = Client(username, password, apikey)
    identities = api.authenticate.get_identities()
    identity_tuples = [(i, x['Id'], x['Client']['Name']) for i, x in enumerate(identities['results'])]
    if trans:
        trans_count = 0
    if account:
        account_count = 0
    for i, tup in enumerate(identity_tuples):
        if account:
            for index in range(0, retries):
                try:
                    api = Client(username, password, apikey)
                    api.authenticate.set_identity_by_id(tup[1])
                    temp_dict = api.accounts.get_account_list()
                    account_count += temp_dict['count']
                except:
                    if index+1==retries:
                        raise
                    continue
                break
            temp_df = pd.DataFrame(temp_dict['results'])
            temp_df['ClientName'] = tup[2]
            if i==0:
                acc_df = temp_df.copy()
            else:
                acc_df = acc_df.append(temp_df)
            logging.info('Account data loaded for {}'.format(tup[2]))
        if trans:
            for index in range(0, retries):
                try:
                    api = Client(username, password, apikey)
                    api.authenticate.set_identity_by_id(tup[1])
                    temp_dict = api.transactions.get_transactions(**kwargs)
                    trans_count += temp_dict['count']
                except:
                    if index+1==retries:
                        raise
                    continue
                break
            if temp_dict['count']==0:
                continue
            temp_df_dims = pd.json_normalize(temp_dict['results'], ['Dimensions', 'Dimension'], 'Id')
            temp_df = pd.json_normalize(temp_dict['results'])
            temp_df['ClientName'] = tup[2]
            temp_df_dims['ClientName'] = tup[2]
            if i==0:
                trans_df_dims = temp_df_dims.copy()
                trans_df = temp_df.copy()
            else:
                trans_df_dims = trans_df_dims.append(temp_df_dims)
                trans_df = trans_df.append(temp_df)
            logging.info('Transaction data loaded for {}'.format(tup[2]))
    if trans:
        if trans_count==0:
            trans_df = pd.DataFrame(columns = trans_dest_dtypes.keys())
            logging.info('No transactions found for the given search parameters. Writing empty dataframe')
        else:
            trans_df_dims = trans_df_dims.set_index(['ClientName','Id']).pivot(columns='Type')
            trans_df_dims.columns = trans_df_dims.columns.get_level_values(1) + trans_df_dims.columns.get_level_values(0)
            trans_df = trans_df.merge(trans_df_dims, how = 'left', left_on = ['ClientName', 'Id'], right_index = True)\
                    .drop(['Dimensions', 'Dimensions.Dimension'], axis = 1)
            for col in [x for x in trans_df]:
                if 'Date' in col:
                    trans_df[col] = pd.to_datetime(trans_df[col], utc=True).dt.tz_localize(None).astype(np.datetime64)
                if trans_dest_dtypes[col] == 'int':
                    trans_df[col] = trans_df[col].astype('Int64')
    if account:
        if account_count==0:
            acc_df = pd.DataFrame(columns = acc_dest_dtypes.keys())
            logging.info('No account information found for the given search parameters. Writing empty dataframe')
        else:
            for col in [x for x in acc_df]:
                if acc_dest_dtypes[col] == 'int':
                    acc_df[col] = acc_df[col].astype('Int64')
    containerName='functions'
    index=None
    encoding='utf-8'
    sep='|'
    if account:
        dest_account_table = '24SO_Account'
        blobService.create_blob_from_text(containerName, '{}.csv'.format(dest_account_table), acc_df.to_csv(index=index,encoding = encoding, sep=sep))
        logging.info('Account data written to blob')
    if trans:
        dest_transaction_table = '24SO_Transaction'
        blobService.create_blob_from_text(containerName, '{}.csv'.format(dest_transaction_table), trans_df.to_csv(index=index,encoding = encoding, sep=sep))
        logging.info('Transaction data written to blob')
    return True

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    api_username_alias='UID'
    api_password_alias='PWD'
    api_apikey_alias='KEY'
    start_date_alias='START_DATE'
    end_date_alias='END_DATE'
    account_name_alias='BLOB_ACCOUNT_NAME'
    account_key_alias='BLOB_ACCOUNT_KEY'

    api_username = set_param(req, api_username_alias)
    api_password = set_param(req, api_password_alias)
    api_apikey = set_param(req, api_apikey_alias)
    account_name=set_param(req, account_name_alias)
    account_key=set_param(req, account_key_alias)
    start_date=set_param(req, start_date_alias)
    end_date=set_param(req, end_date_alias)
    #api_username = req.params.get(api_username_alias)

    #api_password = req.params.get('PWD')
    #api_apikey = req.params.get('KEY')

    blobService = BlockBlobService(account_name=account_name, account_key=account_key)

    logging.info('Processing main function...')
    success = load_from_24so(api_username, api_password, api_apikey, date_start=start_date,
                            date_end=end_date,blobService=blobService, trans_dest_dtypes=trans_dest_dtypes,
                            acc_dest_dtypes=acc_dest_dtypes)

    logging.info('Main function processed successfully: {}'.format(success))

    if success:
        return func.HttpResponse(json.dumps({"message":"Load completed without error"}),mimetype="application/json")
    else:
        return func.HttpResponse(
             json.dumps({"message":"Please pass a name on the query string or in the request body"}),mimetype="application/json",
             status_code=400
        )