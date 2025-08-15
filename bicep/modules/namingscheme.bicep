@sys.description('The point of this module us to return names that conform to some naming scheme')

@description('name of the workload - this is the only parameter')
param workload string

var sharedNameVars = loadJsonContent('../sharedNameVars.json')

var organisation = sharedNameVars.organisation
var shortLocation = sharedNameVars.location
var environment = sharedNameVars.environment

var longName = '${shortLocation}-${organisation}-${workload}-${environment}'

@description('Name for a storage account - conforms to azure naming and length restrictions')
var storageAccountName = toLower(take('st${shortLocation}${organisation}${workload}${environment}${uniqueString(resourceGroup().id)}', 24))
@description('Name for a keyvault')
var keyvaultName = toLower(take('kv-${longName}', 24))
@description('Name for a function app')
var functionAppName = toLower(take('func-${longName}${uniqueString(resourceGroup().id)}', 60))
@description('Name for a hosting plan - conforms to azure naming and length restrictions')
var hostingPlanName = toLower(take('asp-${longName}', 60))
@description('Name for an action group - conforms to azure naming and length restrictions')
var actionGroupName = toLower(take('ag-${longName}', 260))
@description('Name for an alert - conforms to azure naming and length restrictions')
var alertName = toLower(take('apr-${longName}', 260))
@description('Name for an insights resource - conforms to azure naming and length restrictions')
var insightsName = toLower(take('appi-${longName}', 60))


output storageAccountName string = storageAccountName
output keyvaultName string = keyvaultName
output functionAppName string = functionAppName
output hostingPlanName string = hostingPlanName
output actionGroupName string = actionGroupName
output alertName string = alertName
output insightsName string = insightsName
output longName string = longName


