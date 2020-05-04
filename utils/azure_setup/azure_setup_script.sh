############################ #
# Dette scriptet må enten kjøres fra en datamaskin hvor du har rettigheter til å
# installere Azure CLI eller fra Azures Cloud Shell (https://shell.azure.com/).
# Scriptet vil automatisk bruke din VS-subscription om dette har "Visual Studio" i navnet
#
# Scriptet oppretter:
# - En resource group som holder alle ressursene
# - En Azure Key Vault som holder alle passord og nøkler (Husk å gi KEY_VAULT_NAME et unikt navn)
# - En Azure SQL Database med et ferdigdefinert schema basert på en .bacpac-fil
# - En Storage-konto med tilhørende container (Husk å gi STORAGE_ACCOUNT_NAME et unikt navn)
# - En Azure Data Factory med flyter for å hente data fra 24SevenOffice og gjøre det klart for analyse i Power BI
# - En Python Function App
# For å slette ressursgruppen: 
# Kjør: az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION
# 
############################# #

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

# Install Azure CLI (Linux-versjon)
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 

# Login (open in IE hvis du har problemer i Chrome)
#az login

### Input parameters
#Project name should be only alphanumeric characters
echo "Input your desired project name. All characters must be alphanumeric:"
read -p "Project name: " PROJECT_NAME

while [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9] ]]
  do
    echo "Invalid project name. Remember that all characters must be alphanumeric"
    echo "Input your desired project name:"
    read -p "Project name: " PROJECT_NAME
  done

echo "Input your public ip address, which you can find på googling \"my ip\""
read -p "IP Address: " MY_IP_ADDRESS
while ! [[ $MY_IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
  do
    echo "Invalid IP address. Please enter your IP address:"
    read MY_IP_ADDRESS
  done

#PROJECT_NAME=
#DBSERVER_ADMIN_PASSWORD=

RESOURCE_GROUP=rg-$PROJECT_NAME
RESOURCE_LOCATION=northeurope

## Storage Account
STORAGE_ACCOUNT_NAME=st${PROJECT_NAME}

# Storage account name must be unique
NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)

while [ $NAME_AVAILABLE = 'false' ]
  do
    echo "Storage account name $STORAGE_ACCOUNT_NAME is taken, please choose a different name:"
    read -p "Storage account name: " STORAGE_ACCOUNT_NAME
    NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)
  done

STORAGE_CONTAINER=data-factory-staging
STORAGE_SKU=Standard_LRS

BACPAC_CONTAINER=bacpac
BACPAC_NAME=db-template.bacpac

FUNCTIONS_CONTAINER=functions

MANUAL_INPUT_CONTAINER=data-factory-manual-input

## Database
DBSERVER_ADMIN_USER=serveradmin

# Database server password.
echo "Input your desired database server password"
echo "The password cannot contain the username, ${DBSERVER_ADMIN_USER}, and must contain at least three of the following:"
echo "* An uppercase letter"
echo "* A lowercase letter"
echo "* A number"
echo "* A special character like !, $, % or #"
echo "No data validation is implemented, so take care when selecting your password"
read -p "DB server admin password: " DBSERVER_ADMIN_PASSWORD

DBSERVER_NAME=sql-$PROJECT_NAME
DB_NAME=sqldb-$PROJECT_NAME
DB_EDITION=Basic #Allowed values include: Basic, Standard, Premium, GeneralPurpose, BusinessCritical, Hyperscale
MAX_SIZE=1GB

### Key Vault
# Key Vault name must be unique
KEY_VAULT_NAME=kv-$PROJECT_NAME
ARM_TEMPLATE_FILE=arm_template.json
DATA_FACTORY_NAME=adf-$PROJECT_NAME-dev

# Find Visual Studio Enterprise Subscription, otherwise find your
SUBSCRIPTION=$(az account list --query "[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID" -o tsv)

## Function App
# Function App name must be unique
FUNCTION_APP_NAME=func-$PROJECT_NAME

# Execute script_variables each time a new variable is defined
script_variables || true

############################# #
# Create resource group
############################# #

az group create \
  --name $RESOURCE_GROUP \
  --location $RESOURCE_LOCATION \
  --subscription $SUBSCRIPTION

############################# #
# Create Key Vault
############################# #

# Key vault may fail with a HTTP error. Most times the session must be restarted, but attempting retry first
n=0
retries=3
until [ $n -ge $retries ]
do
   az keyvault create\
   --location $RESOURCE_LOCATION\
   --name $KEY_VAULT_NAME\
   --enable-soft-delete true\
   --resource-group $RESOURCE_GROUP && break
   n=$[$n+1]
   sleep 15
done
  
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

STORAGE_ACCOUNT_KEY1=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

script_variables || true

# Create secret to store storage account key
az keyvault secret set\
  --name $STORAGE_ACCOUNT_NAME\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $STORAGE_ACCOUNT_KEY1

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


# Get first storage account key

PRIMARY_ENDPOINT_STORAGE=$(az storage account show --name $STORAGE_ACCOUNT_NAME --query primaryEndpoints.blob -o tsv)
STORAGE_URI=${PRIMARY_ENDPOINT_STORAGE}${BACPAC_CONTAINER}/$BACPAC_NAME

SOURCE_STORAGE_ACCOUNT_NAME=sharingiscaring01
SOURCE_CONTAINER=data-factory-manual-input

DF_SHARED_ACCESS_KEY="se=2025-01-01&sp=rl&sv=2018-11-09&sr=c&sig=KALHqnqoykOnMk0FFFZS%2B1jMutBEP5z7WgGzr9aO3X8%3D"
BACPAC_SHARED_ACCESS_KEY="se=2025-01-01&sp=rl&sv=2018-11-09&sr=c&sig=m6ZcmWUfCg/Jj3RizJtl0dMExNBWuw10Iu/P3m9yWHU%3D"

script_variables || true

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

# Get the function app key
FUNCTION_APP_KEY=$(az rest --method post --uri "/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/host/default/listKeys?api-version=2018-11-01" --query functionKeys.default -o tsv)

script_variables || true

# Upload bacpac file to blob
#az storage blob upload --file $BACPAC_NAME\
#                       --name $BACPAC_NAME\
#                       --container-name $BACPAC_CONTAINER\
#                       --account-name $STORAGE_ACCOUNT_NAME \
#                       --account-key $STORAGE_ACCOUNT_KEY1

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

# Create secret to store database server admin password
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

# Populate database with data/schema from bacpac file stored in blob
az sql db import --resource-group $RESOURCE_GROUP\
                 --server $DBSERVER_NAME\
                 --name $DB_NAME\
                 --admin-user $DBSERVER_ADMIN_USER\
                 --admin-password $DBSERVER_ADMIN_PASSWORD\
                 --storage-key $STORAGE_ACCOUNT_KEY1\
                 --storage-key-type StorageAccessKey\
                 --storage-uri $STORAGE_URI

# Get uri of Key Vault secret containing DB password
DBSERVER_ADMIN_PASSWORD_URI=$(az keyvault secret show --name $DBSERVER_NAME --vault-name $KEY_VAULT_NAME --query id -o tsv)

script_variables || true

############################# #
# Deploy empty Data Factory
############################# #

az resource create --resource-group $RESOURCE_GROUP\
                   --name $DATA_FACTORY_NAME\
                   --is-full-object --resource-type "Microsoft.DataFactory/factories"\
                   --properties "{\"location\": \"${RESOURCE_LOCATION}\", \"identity\": {\"type\": \"SystemAssigned\"}}"


# Get Data Factory principal ID and allow Data Factory to get and list secrets in Azure Key Vault
DATA_FACTORY_PRINCIPAL_ID=$(az resource list -n $DATA_FACTORY_NAME -g $RESOURCE_GROUP --resource-type "Microsoft.DataFactory/factories" --query [0].identity.principalId -o tsv)

script_variables || true

#az group deployment create --resource-group $RESOURCE_GROUP\
                           #--mode Incremental\
                           #--subscription $SUBSCRIPTION\
                           #--template-file $ARM_TEMPLATE_FILE\
                           #--parameters @$ARM_TEMPLATE_PARAMETER_FILE


az keyvault set-policy -n $KEY_VAULT_NAME --object-id $DATA_FACTORY_PRINCIPAL_ID --secret-permissions get list

############################# #
# Tear it all down
############################# #
 
# Delete all assets
# az group delete --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION

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

# Remove temporary files
rm /tmp/variables.before /tmp/variables.after
