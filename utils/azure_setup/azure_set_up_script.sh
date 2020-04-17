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

# Install Azure CLI (Linux-versjon)
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 

# Login (open in IE hvis du har problemer i Chrome)
#az login

### Input parameters
#Project name should be only alphanumeric characters
echo "Input your desired project name. All characters must be alphanumeric:"
read PROJECT_NAME

if [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9] ]]; then
  echo "Invalid project name. Remember that all characters must be alphanumeric"
  echo "Input your desired project name:"
  read PROJECT_NAME
fi

# Database server password. Generate password from https://passwordsgenerator.net/
echo "Input your desired database server password:"
read DBSERVER_ADMIN_PASSWORD

#PROJECT_NAME=
#DBSERVER_ADMIN_PASSWORD=

RESOURCE_GROUP=$PROJECT_NAME-RG
RESOURCE_LOCATION=northeurope

## Storage Account
STORAGE_ACCOUNT_NAME=${PROJECT_NAME}storage

# Storage account name must be unique. Append 1's until it is
NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)

if [ $NAME_AVAILABLE = 'false' ]
  then
    while [ $NAME_AVAILABLE = 'false' ]
      do
        STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME}1
        NAME_AVAILABLE=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} --query nameAvailable -o tsv)
      done
fi

STORAGE_CONTAINER=data-factory-staging
STORAGE_SKU=Standard_LRS

BACPAC_CONTAINER=bacpac
BACPAC_NAME=db-template.bacpac

FUNCTIONS_CONTAINER=functions

MANUAL_INPUT_CONTAINER=data-factory-manual-input

## Database
DBSERVER_ADMIN_USER=serveradmin
DBSERVER_NAME=$PROJECT_NAME-sqlserver
DB_NAME=$PROJECT_NAME-db
DB_EDITION=Basic #Allowed values include: Basic, Standard, Premium, GeneralPurpose, BusinessCritical, Hyperscale
MAX_SIZE=1GB

### Key Vault
# Key Vault name must be unique
KEY_VAULT_NAME=$PROJECT_NAME-KV
ARM_TEMPLATE_FILE=arm_template.json
DATA_FACTORY_NAME=$PROJECT_NAME-adf-dev

# Find Visual Studio Enterprise Subscription, otherwise find your
SUBSCRIPTION=$(az account list --query "[].{Name:name, ID:id}[?contains(Name,'Visual Studio')].ID" -o tsv)

## Function App
# Function App name must be unique
FUNCTION_APP_NAME=$PROJECT_NAME-func

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

az keyvault create\
   --location $RESOURCE_LOCATION\
   --name $KEY_VAULT_NAME\
   --resource-group $RESOURCE_GROUP
  
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
az sql server create --admin-password $DBSERVER_ADMIN_PASSWORD\
                     --admin-user $DBSERVER_ADMIN_USER\
                     --name $DBSERVER_NAME\
                     --resource-group $RESOURCE_GROUP\
                     --location $RESOURCE_LOCATION\
                     --subscription $SUBSCRIPTION

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

# Populate database with data/schema from bacpac file stored in blob
az sql db import --resource-group $RESOURCE_GROUP\
                 --server $DBSERVER_NAME\
                 --name $DB_NAME\
                 --admin-user $DBSERVER_ADMIN_USER\
                 --admin-password $DBSERVER_ADMIN_PASSWORD\
                 --storage-key $STORAGE_ACCOUNT_KEY1\
                 --storage-key-type StorageAccessKey\
                 --storage-uri $STORAGE_URI

############################# #
# Deploy empty Data Factory
############################# #

az resource create --resource-group $RESOURCE_GROUP\
                   --name $DATA_FACTORY_NAME\
                   --is-full-object --resource-type "Microsoft.DataFactory/factories"\
                   --properties "{\"location\": \"${RESOURCE_LOCATION}\", \"identity\": {\"type\": \"SystemAssigned\"}}"


# Get Data Factory principal ID and allow Data Factory to get and list secrets in Azure Key Vault
DATA_FACTORY_PRINCIPAL_ID=$(az resource list -n $DATA_FACTORY_NAME -g $RESOURCE_GROUP --resource-type "Microsoft.DataFactory/factories" --query [0].identity.principalId -o tsv)

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

API_KEY_24SO=d887b94b-f831-4bc9-9500-bd7a63875d9c

az keyvault secret set\
  --name apikey24SO\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $API_KEY_24SO

API_PWD_24SO=@PwCBergen2020!

az keyvault secret set\
  --name apipwd24SO\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $API_PWD_24SO

# Get function app key from portal and add it to key vault
echo "Get your function app key from the portal and paste it here. If you would like to add your function app key later, input \"temp\" and proceed"
read FUNCTION_APP_KEY
#FUNCTION_APP_KEY=temp

az keyvault secret set\
  --name $FUNCTION_APP_NAME\
  --vault-name $KEY_VAULT_NAME\
  --subscription $SUBSCRIPTION\
  --value $FUNCTION_APP_KEY

SQL_CON='Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=@{linkedService().datasourceprefix}.database.windows.net;Initial Catalog=@{linkedService().dbname};User ID=@{linkedService().sqlusername}'
BLOB_CON='DefaultEndpointsProtocol=https;AccountName=@{linkedService().accountname};'
KV_URL='https://@{linkedService().keyvaultname}.vault.azure.net/'


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
      \"sqldbname\": {
          \"value\": \"${DB_NAME}\"
      },
      \"blobaccountname\": {
          \"value\": \"${BLOB_ACCOUNT_NAME}\"
      },
      \"keyvaultname\": {
          \"value\": \"${KEY_VAULT_NAME}\"
      },
      \"functionappname\": {
          \"value\": \"${FUNCTION_APP_NAME}\"
      }
  }
}"