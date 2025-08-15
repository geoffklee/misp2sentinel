param storageAccountName string
param location string
param storageAccountType string
param tagValues object = {}
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string 
param networkACLs object = {}

module storageAccount 'br/public:avm/res/storage/storage-account:0.13.0' = {
  name: 'storageAccountDeployment'
  params: {
    // Required parameters
    name: storageAccountName
    // Non-required parameters
    kind: 'StorageV2'
    location: location
    skuName: storageAccountType
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkACLs
    tags: tagValues
    blobServices: {
      containers: [
        {
          name: 'scm-releases'
        }
      ]
    }
  }
}

output name string = storageAccountName
output resourceId string = storageAccount.outputs.resourceId
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint

