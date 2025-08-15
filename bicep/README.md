# Bicep deployment files

The script `deploy.sh` can be used with the bicep files in this directory to deploy a complete set of resources for this connector.

## Prerequisites
You will need to have the following:
* The az cli installed
* The necessary permissions to create resources in your resource group
* Permissions to create an App Registration in Entra (see bottom of this document)

## A note on networking
The recommended configuration to allow the Function App to securely access the storage account and Key Vault is 
to use [Virtual Network (vnet) Integration](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options?tabs=azure-portal#virtual-network-integration)

> **WARNING**: If VNet integration is not enabled (default), all services are created with unrestricted public network access.

### Function App VNet Integration
The bicep code won't attempt to create a virtual network or subnet, but you can enable virtual network integration on the function app by passing in the ID of a pre-existing subnet for it to integrate with.

- Enable with: `enableFunctionAppVNetIntegration = true`
- Requires: `functionAppSubnetId` - Resource ID of a **delegated subnet** for Microsoft.App/environments
- The function app subnet must be delegated to `Microsoft.App/environments` and must also have service endpoints
enabled for Storage and KeyVault

When VNet integration is enabled:
- The key vault and storage account have access restricted to only the integrated subnet; however, you can 
specify additional IP ranges (eg your development PC) to have access through the `additionalAllowedNetworksKeyVault` and `additionalAllowedNetworksStorage` parameters.

## Instructions
* Clone this repository
* `cd` to the `bicep` directory
* Copy the `misp2sentinel.example.bicepparam` file to `misp2sentinel.bicepparam` and set values appropriately
* Update the values in `sharedNameVars.json`: you may want to rework `modules/namingscheme.bicep` to suit your environment
* run `az login` to ensure you are logged into the relevant Azure tenancy
* run `./deploy.sh <subscription_name> <resource_group_name> <location> yes` (all parameters are mandatory; the final one controls whether the code is deployed after the infrastructure is created)

# What does it do?
We create the following:

* An Azure functions app using the Flex Consumption plan
* An App Service Plan for the app (consumption based)
* A storage account for the web app (necessary on the consumption plan)
* A key vault (to store secrets)
* An applicationInsights instance
* An alert rule to notify an email address of any failures

Once the resources are created, the script will attempt to use the `az functionapp deployment` command to deploy the code to the function app.

# Secrets and app registration
Once deployed, you need to manually create the following two secrets in the Key vault:

* ClientSecret - the Client Secret for the App Registration that the app uses to authenticate
* MISP-Key - The API key for the MISP service you are accessing

Client Secret will be obtained when you [Register an Entra app](https://www.misp-project.org/2023/04/03/MISP-Sentinel.html/#:~:text=Azure%20App%20registration)