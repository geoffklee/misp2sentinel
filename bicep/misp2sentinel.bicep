@description('Optional list of additional IP addresses or CIDR subnets to allow access to Key Vault')
param additionalAllowedNetworksKeyVault array = []

@description('Optional list of additional IP addresses or CIDR subnets to allow access to Key Vault')
param additionalAllowedNetworksStorage array = []

@description('Optional list of additional IP addresses or CIDR subnets to allow access to the Function App')
param additionalAllowedNetworksApp array = []

@description('Enable VNet integration')
param enableVNetIntegration bool = false

@description('Resource ID of the existing delegated subnet for Function App VNet integration (must be delegated to Microsoft.Web/serverFarms)')
param functionAppSubnetId string = ''

@description('Name of the workload')
param workloadName string

@description('The URL to the MISP server')
param mispURL string

@description('JSON string representing the MISP event filters')
param mispEventFilters string = '{"published":1,"publish_timestamp":"24h","enforceWarninglist":true,"includeEventTags":true}'

@description('ID of the tenant containing the target Sentinel workspace')
param tenantID string = tenant().tenantId

@description('ID of sentinel workspace you want to target')
param sentinelWorkspaceID string

@description('Client ID of the App registration used to authenticate to Azure')
param clientID string

@description('Crontab representation of how often you want the connector to run')
param triggerSchedule string

@description('Alert email recipient address')
param alertEmailRecipientAddress string

@description('Alert email recipient name')
param alertEmailRecipientName string

@description('Tags to be applied to all resources')
param tagValues object

@description('Location for all resources.')
param location string = resourceGroup().location

module namingScheme './modules/namingscheme.bicep' = {
  name: 'namingScheme'
  params: {
    workload: workloadName
  }
}

module vault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'vaultDeployment'
  params: {
    // Required parameters
    name: namingScheme.outputs.keyvaultName
    // Non-required parameters
    enablePurgeProtection: false
    enableRbacAuthorization: true
    location: location
    sku: 'standard'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: enableVNetIntegration ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: [for network in additionalAllowedNetworksKeyVault: {
        value: network
        action: 'Allow'
      }]
      virtualNetworkRules: enableVNetIntegration ? [
        {
          id: functionAppSubnetId
          action: 'Allow'
        }
      ] : []
    }
  }
}

@description('Storage account for deploymemnt')
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: namingScheme.outputs.storageAccountName
    location: location 
    tagValues: tagValues
    storageAccountType: 'Standard_LRS'
    // Unless private endpoints, we need to allow public 
    // access, or the function app can't access us.
    publicNetworkAccess: 'Enabled'
    networkACLs: {
      defaultAction: enableVNetIntegration ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: [for network in additionalAllowedNetworksStorage: {
        value: endsWith(network, '/32') ? substring(network, 0, length(network) - 3) : network
        action: 'Allow'
      }]
      virtualNetworkRules: enableVNetIntegration ? [
        {
          id: functionAppSubnetId
          action: 'Allow'
        }
      ] : []
    }
  }
}

module hostingPlan 'modules/flexhostingplan.bicep' = {
  name: 'hostingPlan'
  params: {
    hostingPlanName: namingScheme.outputs.hostingPlanName
    location: location
    tagValues: tagValues
  }
}

module functionApp './modules/app.bicep' = { 
  name: 'functionApp'
  params: {
    functionAppName: namingScheme.outputs.functionAppName
    location: location
    tagValues: tagValues
    storageAccountName: storage.outputs.name
    hostingPlanId: hostingPlan.outputs.hostingPlanId
    allowedNetworksApp: additionalAllowedNetworksApp
    enableVNetIntegration: enableVNetIntegration
    vnetIntegrationSubnetId: functionAppSubnetId
    appSettingsAdditions: [ 
      { name: 'APPINSIGHTS_INSTRUMENTATIONKEY' 
        value: failureNotification.outputs.applicationInsightsInstrumentationKey
      }
      { name: 'APPINSIGHTS_CONNECTION_STRING' 
        value: failureNotification.outputs.applicationInsightsConnectionString
      }
      {
        name: 'key_vault_name'
        value: vault.outputs.name
      }
      {
        name: 'mispurl'
        value: mispURL
      }
      {
        name: 'client_id'
        value: clientID
      }
      {
        name: 'tenant_id'
        value: tenantID
      }
      {
        name: 'workspace_id'
        value: sentinelWorkspaceID
      }
      {
        name: 'timerTriggerSchedule'
        value: triggerSchedule
      } 
      {
        name: 'misp_event_filters'
        value: mispEventFilters
      }
    ]
    deploymentConfig: {
      storage: {
        type: 'blobContainer'
        value: '${storage.outputs.primaryBlobEndpoint}scm-releases'
        authentication: {
          type: 'SystemAssignedIdentity'
        }
      }
    }
  }
}

// Assign the function app rights to the storage account without
// creating a cyclic dependency
module roleAssignmentFuncAppToStorage 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.0' = {
  name: 'roleAssignmentFuncAppToStorage'
  params: {
    // Required parameters
    principalId: functionApp.outputs.managedIdentityPrincipalId
    resourceId: storage.outputs.resourceId
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    // Non-required parameters
    description: 'Assign Storage Blob Data Owner on the storage account to the function app'
    principalType: 'ServicePrincipal'
    // As per https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=blob&pivots=programming-language-python#connecting-to-host-storage-with-an-identity
    roleName: 'Storage Blob Data Owner'
  }
}

// Assign the function account rights to the keyvault
module roleAssignmentFuncAppToKeyVault 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.0' = {
  name: 'roleAssignmentFuncAppToKeyVault'
  params: {
    // Required parameters
    principalId: functionApp.outputs.managedIdentityPrincipalId
    resourceId: vault.outputs.resourceId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    // Non-required parameters
    description: 'Assign Key Vault Secrets User on the Key Vault to the function account'
    principalType: 'ServicePrincipal'
    roleName: 'Key Vault Secrets User'
  }
}


module failureNotification 'modules/notification.bicep' = {
  name: 'failureNotification'
  params:{
    notificationName: namingScheme.outputs.alertName
    actionGroupName: namingScheme.outputs.actionGroupName
    applicationInsightsName: namingScheme.outputs.insightsName
    location: location
    tags: tagValues
    workloadName: workloadName
    alertEmailRecipientAddress: alertEmailRecipientAddress
    alertEmailRecipientName: alertEmailRecipientName
  }
}





output appName string = functionApp.outputs.functionAppName
output storageAccountName string = storage.outputs.name
output keyVaultName string = vault.outputs.name
