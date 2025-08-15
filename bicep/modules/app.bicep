param functionAppName string
param location string
param tagValues object
param hostingPlanId string
param storageAccountName string
param deploymentConfig object = {}
param appSettingsAdditions array = []
param allowedNetworksApp array = []
param enableVNetIntegration bool = false
param vnetIntegrationSubnetId string = ''


resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tagValues
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlanId
    functionAppConfig: {
      // Allow this to be overridden but provide a default configuration
      deployment: deploymentConfig
      runtime: { 
        name: 'python'
        version: '3.12'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        // 512 is accepted by Bicep but seems unstable.
        // Portal minimum is 2048
        instanceMemoryMB: 2048
      }
    }
    siteConfig: {
      // NB you need access to the SCM interface from wherever 
      // you're publishing the app from!
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions: map(allowedNetworksApp, ip => {
        ipAddress: ip
        action: 'Allow'
      })
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictions: map(allowedNetworksApp, ip => {
        ipAddress: ip
        action: 'Allow'
      })
      //linuxFxVersion: runtime
      appSettings: concat(appSettingsAdditions,[

        // This setting causes us to connect with managed identity 
        // rather than connection strings
        {
           name: 'AzureWebJobsStorage__accountName'
           value: storageAccountName
        }
        {
         name: 'FUNCTIONS_EXTENSION_VERSION'
         value: '~4'
        }
      ])
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
    virtualNetworkSubnetId: enableVNetIntegration ? vnetIntegrationSubnetId : null
  }
}


output managedIdentityPrincipalId string = functionApp.identity.principalId
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
