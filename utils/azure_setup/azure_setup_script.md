
# Azure Setup Script

The `azure_set_up_script.sh` script is designed to be executed in the Azure Cloud Shell.
The script sets up a resource group containing the following resources:

* An Azure Key Vault for storing passwords and keys

* An Azure SQL Database with a predefined schema based on a .bacpac-file

* An Azure Storage Account containing several storage containers

* An Azure Functions app which integrates the 24SevenOffice SOAP API with the Azure SQL Database

* An Azure Data Factory with data flows and orchestrations which gathers data from 24SevenOffice and prepares it for analysis in Power BI

If you which to delete the resource group you have created, you may to so by running this code:

`az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION`

## Shell script

Set that execution of the script should stop if an error occurs.
Store existing variables in a temporary file so you can keep track of the new variables defined in the script.
Define a function that writes to a file called `variables.txt` which contains the variables defined in the script.
This may be useful if execution of the script stops and you want to copy and run the remaining commands line-by-line in the Cloud Shell.

```bash
#!/bin/bash
set -e

# Find variables defined before execution of the script and store them in a temporary file
( set -o posix ; set ) >/tmp/variables.before

# Define function to store variables defined in script
function script_variables()
{
# Find variables defined before execution of the script and in the script and store them in a temporary file
( set -o posix ; set ) >/tmp/variables.after

# Find variables defined only in script and write to variables.txt
diff /tmp/variables.before /tmp/variables.after > variables.txt

# Delete unwanted rows from variables.txt and clean output
sed -i '/^\(>\)/!d' variables.txt
sed -i 's/^..//' variables.txt
}
```

### Variable definition

#### User inputs

The project name should be only alphanumeric characters as the storage account name is derived from the project name and can only contain alphanumeric characters.

Prompt the user for their project name. If the user enters an invalid project name, they will be prompted to input a different project name until they have entered a valid name.

```bash
#Project name should be only alphanumeric characters
echo "Input your desired project name. All characters must be alphanumeric:"
read PROJECT_NAME

while [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9] ]]
  do
    echo "Invalid project name. Remember that all characters must be alphanumeric"
    echo "Input your desired project name:"
    read PROJECT_NAME
  done
```

Ask the user for their public IP address in order to set up a SQL Server firewall rule allowing access from this IP.

The IP address must be valid in order to proceed. 

```bash
echo "Input your public ip address, which you can find på googling \"my ip\""
read MY_IP_ADDRESS
while ! [[ $MY_IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
  do
    echo "Invalid IP address. Please enter your IP address:"
    read MY_IP_ADDRESS
  done
```

#### Derived resource names

The names of are based on Azure naming recommendations. A prefix is added to the project name depending on the resource in question.

```bash
RESOURCE_GROUP=rg-$PROJECT_NAME
RESOURCE_LOCATION=northeurope

## Storage Account
STORAGE_ACCOUNT_NAME=st${PROJECT_NAME}
```

The storage account name is set to st{PROJECT_NAME} by default. The storage account name must be unique. If the name is not available, you are prompted for a new name until you choose a name that is available

```bash
# Storage account name must be unique
NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)

while [ $NAME_AVAILABLE = 'false' ]
  do
    echo "Storage account name $STORAGE_ACCOUNT_NAME is taken, please choose a different name:"
    read STORAGE_ACCOUNT_NAME
    NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)
  done
```

Create storage containers that you will require and set a storage tier

```bash
STORAGE_CONTAINER=data-factory-staging
STORAGE_SKU=Standard_LRS

BACPAC_CONTAINER=bacpac
BACPAC_NAME=db-template.bacpac

FUNCTIONS_CONTAINER=functions

MANUAL_INPUT_CONTAINER=data-factory-manual-input
```

Set the server admin user name to *serveradmin* and prompt the user for the password. No password validation is done here. If the password is not accepted later on, it is set to *@PwCBergen2020!* by default.


```bash
## Database
DBSERVER_ADMIN_USER=serveradmin

# Database server password.
echo "Input your desired database server password"
echo "The password cannot contain the username, ${DBSERVER_ADMIN_USER}, and must contain at least three of the following: an uppercase letter, a lowercase letter, a number, a special character like !, $, % or #"
echo "No data validation is implemented, so take care when selecting your password"
read DBSERVER_ADMIN_PASSWORD

DBSERVER_NAME=sql-$PROJECT_NAME
DB_NAME=sqldb-$PROJECT_NAME
DB_EDITION=Basic #Allowed values include: Basic, Standard, Premium, GeneralPurpose, BusinessCritical, Hyperscale
MAX_SIZE=1GB
```

Name key vault and data factory according to Azure recommendations. Set the name of the arm template file you have uploaded from the Cloud Shell. The ARM template is a textual representation of the Data Factory you will create.

```bash
### Key Vault
# Key Vault name must be unique
KEY_VAULT_NAME=kv-$PROJECT_NAME
ARM_TEMPLATE_FILE=arm_template.json
DATA_FACTORY_NAME=adf-$PROJECT_NAME-dev
```

This command finds your Visual Studio Enterprise Subscription if you have one.


```
# Find Visual Studio Enterprise Subscription, otherwise find your
SUBSCRIPTION=$(az account list --query "[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID" -o tsv)
```

Explanation of the command:

* `az account list` - Lists information about all subscriptions
* `--query` - Allows you to write a query. The query `"[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID"` gets the ID of the subscription which contains "Visual Studio"
* `-o tsv` - `-o` is shorthand for `--output`. By setting the output to `tsv` you get the result back without quotes

Sets a function name and stores all variables defined so far in variables.txt

```bash
## Function App
# Function App name must be unique
FUNCTION_APP_NAME=func-$PROJECT_NAME

# Execute script_variables each time a new variable is defined
script_variables || true
```

Create your resource group. This will hold all the resources you create


```bash
############################# #
# Create resource group
############################# #

az group create \
  --name $RESOURCE_GROUP \
  --location $RESOURCE_LOCATION \
  --subscription $SUBSCRIPTION
```

Explanation of the command:

* `az group create` - Creates a resource group with the name contained in the variable `$RESOURCE_GROUP`, in the location `$RESOURCE_LOCATION` and under the subscription `$SUBSCRIPTION`

Create a key vault. This command may fail with a HTTP error. Most times the session must be restarted, but attempting three retries first

```bash
############################# #
# Create Key Vault
############################# #

n=0
retries=3
until [ $n -ge $retries ]
do
   az keyvault create\
   --location $RESOURCE_LOCATION\
   --name $KEY_VAULT_NAME\
   --resource-group $RESOURCE_GROUP && break
   n=$[$n+1]
   sleep 15
done
```

Create a storage account

```bash
############################# #
# Create storage account and container (Note! STORAGE_ACCOUNT_NAME must be unique )
############################# #

# Create storage account
az storage account create \
  --name  $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $RESOURCE_LOCATION \
  --sku $STORAGE_SKU \
  --subscription $SUBSCRIPTION
```

Get the storage account key by querying the output from `az storage account keys list`. Running script_variables to save the variables defined in the script to variables.txt every time a new variable is defined.

```bash
STORAGE_ACCOUNT_KEY1=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

script_variables || true
```

Define a secret in the key vault you have created which is given the same name as the storage account and holds the key to the storage account.

```bash
# Create secret to store storage account key
az keyvault secret set\
  --name $STORAGE_ACCOUNT_NAME\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $STORAGE_ACCOUNT_KEY1
```

Create storage empty storage containers

* *data-factory-staging* - Can be used for staging when executing pipelines in Azure Data Factory
* *bacpac* - A .bacpac-file containing the schema for the database you are going to create will be added to this container
* *data-factory-manual-input* - Manual input to the Data Factory will be added to this container
* *functions* - If using a version of the Function App which writes to Blob instead of writing directly to the database, you may use this folder

```bash
# Create storage container for data factory staging  
az storage container create \
  --name $STORAGE_CONTAINER \
  --account-name $STORAGE_ACCOUNT_NAME \
  --subscription $SUBSCRIPTION

# Create storage container for bacpac-file
az storage container create \
  --name $BACPAC_CONTAINER \
  --account-name $STORAGE_ACCOUNT_NAME \
  --subscription $SUBSCRIPTION

# Create storage container for manual input
az storage container create \
  --name $MANUAL_INPUT_CONTAINER \
  --account-name $STORAGE_ACCOUNT_NAME \
  --subscription $SUBSCRIPTION

# Create storage container for azure function output
az storage container create \
  --name $FUNCTIONS_CONTAINER \
  --account-name $STORAGE_ACCOUNT_NAME \
  --subscription $SUBSCRIPTION
```

Get the URI for the .bacpac-file in your storage account.
Define access to my storage account `sharingiscaring01` where you can access using the shared access keys provided below.

```bash
PRIMARY_ENDPOINT_STORAGE=$(az storage account show --name $STORAGE_ACCOUNT_NAME --query primaryEndpoints.blob -o tsv)
STORAGE_URI=${PRIMARY_ENDPOINT_STORAGE}${BACPAC_CONTAINER}/$BACPAC_NAME

SOURCE_STORAGE_ACCOUNT_NAME=sharingiscaring01
SOURCE_CONTAINER=data-factory-manual-input

DF_SHARED_ACCESS_KEY="se=2025-01-01&sp=rl&sv=2018-11-09&sr=c&sig=KALHqnqoykOnMk0FFFZS%2B1jMutBEP5z7WgGzr9aO3X8%3D"
BACPAC_SHARED_ACCESS_KEY="se=2025-01-01&sp=rl&sv=2018-11-09&sr=c&sig=m6ZcmWUfCg/Jj3RizJtl0dMExNBWuw10Iu/P3m9yWHU%3D"

script_variables || true
```

Copy the content of the *data-factory-manual-input* container from `sharingiscaring01` to your storage account. Do the same with the .bacpac-file

```bash
az storage blob copy start-batch --source-sas $DF_SHARED_ACCESS_KEY\
                       --source-container $SOURCE_CONTAINER\
                       --source-account-name $SOURCE_STORAGE_ACCOUNT_NAME\
                       --destination-container $MANUAL_INPUT_CONTAINER\
                       --account-name $STORAGE_ACCOUNT_NAME \
                       --account-key $STORAGE_ACCOUNT_KEY1

az storage blob copy start --source-sas $BACPAC_SHARED_ACCESS_KEY\
                       --source-container $BACPAC_CONTAINER\
                       --source-blob $BACPAC_NAME\
                       --source-account-name $SOURCE_STORAGE_ACCOUNT_NAME\
                       --destination-container $BACPAC_CONTAINER\
                       --destination-blob $BACPAC_NAME\
                       --account-name $STORAGE_ACCOUNT_NAME \
                       --account-key $STORAGE_ACCOUNT_KEY1
```

Create a SQL Server. If the creation fails, change the password to @PwCBergen2020! and retry.


```bash
############################# #
# Create SQL Server and database
############################# #

# Create SQL Server
function create_sql_server()
{
  az sql server create --admin-password $DBSERVER_ADMIN_PASSWORD\
                     --admin-user $DBSERVER_ADMIN_USER\
                     --name $DBSERVER_NAME\
                     --resource-group $RESOURCE_GROUP\
                     --location $RESOURCE_LOCATION\
                     --subscription $SUBSCRIPTION
}



{ # try
    create_sql_server
} || { # catch
    DBSERVER_ADMIN_PASSWORD=@PwCBergen2020!
    create_sql_server
    echo "Your password has been changed to @PwCBergen2020!"
}
```

Create a secret to store database server admin password and create a database on the SQL Server

```bash
az keyvault secret set\
  --name $DBSERVER_NAME\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $DBSERVER_ADMIN_PASSWORD

# Create SQL Database
az sql db create --name $DB_NAME\
                 --resource-group $RESOURCE_GROUP\
                 --server $DBSERVER_NAME\
                 --subscription $SUBSCRIPTION\
                 --edition $DB_EDITION\
                 --max-size $MAX_SIZE
```

Add firewall rules. The first one allows all your Azure resources (like for instance Data Factory) to access the server. The second one allows access from your IP.

```bash
# Allow Azure Services to access the server
az sql server firewall-rule create --resource-group $RESOURCE_GROUP\
                                   --server $DBSERVER_NAME\
                                   --name AllowAzure\
                                   --start-ip-address 0.0.0.0\
                                   --end-ip-address 0.0.0.0

az sql server firewall-rule create --resource-group $RESOURCE_GROUP\
                                   --server $DBSERVER_NAME\
                                   --name MyClientIP\
                                   --start-ip-address $MY_IP_ADDRESS\
                                   --end-ip-address $MY_IP_ADDRESS
```

Populate the database with schema from .bacpac-file stored in blob

```bash
az sql db import --resource-group $RESOURCE_GROUP\
                 --server $DBSERVER_NAME\
                 --name $DB_NAME\
                 --admin-user $DBSERVER_ADMIN_USER\
                 --admin-password $DBSERVER_ADMIN_PASSWORD\
                 --storage-key $STORAGE_ACCOUNT_KEY1\
                 --storage-key-type StorageAccessKey\
                 --storage-uri $STORAGE_URI
```

Get the uri of the Key Vault secret containing DB password. You will require this in the Data Factory pipeline which loads data from 24SevenOffice.

```bash
DBSERVER_ADMIN_PASSWORD_URI=$(az keyvault secret show --name $DBSERVER_NAME --vault-name $KEY_VAULT_NAME --query id -o tsv)

script_variables || true
```

Deploy an empty Data Factory. It is important to set the *identity* property as this creates a Managed Service Identity (MSI) which is necessary to provide Data Factory with the correct permissions in Azure Key Vault.

```bash
############################# #
# Deploy empty Data Factory
############################# #

az resource create --resource-group $RESOURCE_GROUP\
                   --name $DATA_FACTORY_NAME\
                   --is-full-object --resource-type "Microsoft.DataFactory/factories"\
                   --properties "{\"location\": \"${RESOURCE_LOCATION}\", \"identity\": {\"type\": \"SystemAssigned\"}}"
```

Get Data Factory principal ID and allow Data Factory to get and list secrets in Azure Key Vault

```bash
DATA_FACTORY_PRINCIPAL_ID=$(az resource list -n $DATA_FACTORY_NAME -g $RESOURCE_GROUP --resource-type "Microsoft.DataFactory/factories" --query [0].identity.principalId -o tsv)

script_variables || true

az keyvault set-policy -n $KEY_VAULT_NAME --object-id $DATA_FACTORY_PRINCIPAL_ID --secret-permissions get list
```

Deploy a Python 3.7 Function App. This does not deploy any code to your Function App.

```bash
############################# #
# Deploy functionapp
############################# #

az functionapp create --consumption-plan-location $RESOURCE_LOCATION \
                      --os-type Linux \
                      --name $FUNCTION_APP_NAME \
                      --storage-account $STORAGE_ACCOUNT_NAME \
                      --resource-group $RESOURCE_GROUP \
                      --functions-version 2\
                      --runtime python\
                      --runtime-version 3.7\
                      --disable-app-insights true
```

Get the Function App key and store it and the API keys to 24SevenOffice in Key Vault. You will require these in the Data Factory pipeline which loads data from 24SevenOffice.

```bash
FUNCTION_APP_KEY=$(az rest --method post --uri "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/host/default/listKeys?api-version=2018-11-01" --query functionKeys.default -o tsv)

API_KEY_24SO=d887b94b-f831-4bc9-9500-bd7a63875d9c
SECRET_NAME_API_KEY_24SO=apikey24so

script_variables || true

az keyvault secret set\
  --name $SECRET_NAME_API_KEY_24SO\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $API_KEY_24SO

API_KEY_24SO_URI=$(az keyvault secret show --name $SECRET_NAME_API_KEY_24SO --vault-name $KEY_VAULT_NAME --query id -o tsv)

API_PWD_24SO=@PwCBergen2020!
SECRET_NAME_API_PWD_24SO=apipwd24so

script_variables || true

az keyvault secret set\
  --name $SECRET_NAME_API_PWD_24SO\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $API_PWD_24SO

API_PWD_24SO_URI=$(az keyvault secret show --name $SECRET_NAME_API_PWD_24SO --vault-name $KEY_VAULT_NAME --query id -o tsv)

script_variables || true

az keyvault secret set\
  --name $FUNCTION_APP_NAME\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $FUNCTION_APP_KEY

SQL_CON='Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=@{linkedService().datasourceprefix}.database.windows.net;Initial Catalog=@{linkedService().dbname};User ID=@{linkedService().sqlusername}'
BLOB_CON='DefaultEndpointsProtocol=https;AccountName=@{linkedService().accountname};'
KV_URL='https://@{linkedService().keyvaultname}.vault.azure.net/'

script_variables || true
```

Deploy an ARM template to your existing Data Factory which sets up pipelines, connections, datasets and data flows for you.

Provide the appropriate parameters in JSON format to the `--parameters` argument

```bash
az deployment group create --resource-group $RESOURCE_GROUP\
                         --mode Incremental\
                         --subscription $SUBSCRIPTION\
                         --template-file $ARM_TEMPLATE_FILE\
                         --parameters "{
  \"$schema\": \"https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#\",
  \"contentVersion\": \"1.0.0.0\",
  \"parameters\": {
      \"factoryName\": {
          \"value\": \"${DATA_FACTORY_NAME}\"
      },
      \"azure_sql_server_connectionString\": {
          \"value\": \"${SQL_CON}\"
      },
      \"azure_key_vault_properties_typeProperties_baseUrl\": {
          \"value\": \"${KV_URL}\"
      },
      \"azure_blob_storage_connectionString\": {
          \"value\": \"${BLOB_CON}\"
      },
      \"sqlServerName\": {
          \"value\": \"${DBSERVER_NAME}\"
      },
      \"sqlDbName\": {
          \"value\": \"${DB_NAME}\"
      },
      \"blobAccountName\": {
          \"value\": \"${STORAGE_ACCOUNT_NAME}\"
      },
      \"keyVaultName\": {
          \"value\": \"${KEY_VAULT_NAME}\"
      },
      \"functionAppName\": {
          \"value\": \"${FUNCTION_APP_NAME}\"
      },
      \"sqlDbUid\": {
          \"value\": \"${DBSERVER_ADMIN_USER}\"
      },
      \"sqlDbPwdUri\": {
          \"value\": \"${DBSERVER_ADMIN_PASSWORD_URI}\"
      },
      \"apiKey24SoUri\": {
          \"value\": \"${API_KEY_24SO_URI}\"
      },
      \"apiPwd24SoUri\": {
          \"value\": \"${API_PWD_24SO_URI}\"
      }
  }
}"
```

Remove temporary files

```bash
rm /tmp/variables.before /tmp/variables.after
```

```bash
############################# #
# Tear it all down
############################# #
 
# You can uncomment the last row to delete all assets in your resource group
# az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION
```