#!/bin/bash
set -euf -o pipefail
set -x

###############################################################################################
#                                                                                             #
# You need the Azure CLI tools installed                                                      #
#                                                                                             #
###############################################################################################
subscriptionName="${1}"
rgName="${2}"
location="${3}"
deployCode="${4}"

# Make sure we are operating on the subscription we thought we were...
az account set --name $subscriptionName

# Create a resource group if it doesn't exist
az group exists --name "${rgName}" | grep true \
  || az group create --name "${rgName}" --location "${location}" \
     --tags 'Workload=misp2sentinel' 'Environment=sandbox'

# Deploy into the resource group we just created
az deployment group create --resource-group "${rgName}"\
    --template-file misp2sentinel.bicep\
    --parameters misp2sentinel.bicepparam

# Get the name of the deployed app
app_name=$(az deployment group show -g "${rgName}" \
  -n misp2sentinel --query properties.outputs.appName.value \
  --output tsv)

# Redeploy code only if asked...
if [ $4 == 'yes' ]
then
  # Publish to azure and carry out a remote build. 
  ( cd ../AzureFunction
    zip -yr ../AzureFunction-deploy.zip .
    az functionapp deployment source config-zip -g "${rgName}" -n "${app_name}" --src ../AzureFunction-deploy.zip
  )
fi