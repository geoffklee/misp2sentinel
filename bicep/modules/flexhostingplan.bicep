param hostingPlanName string
param tagValues object
param location string
param hostingPlanSKUName string = 'FC1'
param hostingPlanSKUTier string = 'FlexConsumption'

@description('A Flexible Consumption Hosting plan')
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: hostingPlanSKUName
    tier: hostingPlanSKUTier
  }
  // Must set 'kind' and 'properties' as below
  // for a linux hosting plan to be created!
  kind: 'linux'
  properties: {
    reserved: true
  }
  tags: tagValues
}

output hostingPlanId string = hostingPlan.id
