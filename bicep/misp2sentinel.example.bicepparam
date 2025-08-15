using './misp2sentinel.bicep'

// This will be used in the naming of resources, it's best kept short
param workloadName = 'm2s'

// Any tags to be applied to all resources
param tagValues = {
      Workload: 'misp2sentinel'
      Environment: 'sandbox'
      ITOwner: 'bob@example.com'
    }

// The URL of the MISP instance
param mispURL = 'http://misp.example.com'

// ClientId of the service principal that you will use to talk to Sentinel
param clientID = 'xxx'

// ID of the sentinel workspace
param sentinelWorkspaceID = 'fill-this-in-to-activate'

// The schedule for the trigger to run, in CRON format
param triggerSchedule = '0 3 * * *' // daily at 3am

// Email recipient for alerts
param alertEmailRecipientAddress = 'test@example.com'
param alertEmailRecipientName = 'Test user'

// CIDR ranges that should be allowed to access the Key Vault (other than the function app)
param additionalAllowedNetworksKeyVault = []

// CIDR ranges that should be allowed to access the storage account (other than the function app)
param additionalAllowedNetworksStorage = []

// CIDR ranges that should be allowed to access the web interface of the function app
// NB: the machine from which you deploy the function app needs to be able to access the SCM interface
// of the app - so if you are using Vnet integration, and your deployment machine isn't part of the 
// virtual network, you need to add its IP address here.
param additionalAllowedNetworksApp = []

// VNet Integration parameters (optional)
// If you set this to false, all resources will have unrestricted public network access.
// If it is true, you need to specify an appropriate subnet below.
param enableVNetIntegration = true 

// The subnet must be delegated to the Microsoft.App/environments service (you may need 
// enable the Microsoft.App resource provider on your subnet) and it should have service
// endpoints enabled for Key Vault and Storage Account.
param functionAppSubnetId = ''
