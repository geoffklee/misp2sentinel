@description('Name of the notification')
param notificationName string

@description('Name of the action group')
param actionGroupName string

@description('Name for the application insights resource')
param applicationInsightsName string

@description('Location for the resources, when not global')
param location string

@description('Values for tags')
param tags object

@description('Action group resource')
param workloadName string

@description('Alert check frequency')
param alertEvaluationFrequency string = 'PT5M'

@description('Alert check window size')
param alertWindowSize string = 'P1D'

@description('Email address for alert recipient')
param alertEmailRecipientAddress string

@description('Name of the alert email recipient')  
param alertEmailRecipientName string


@description('Generate a notification in case of failures')
resource failureNotification 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: notificationName
  location: 'global'
  tags: tags
  properties: {
    description: '${workloadName}: failure notification'
    severity: 1
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: alertEvaluationFrequency
    windowSize: alertWindowSize
    criteria: {
      allOf: [
        {
          threshold: json('0.0')
          name: 'Metric1'
          metricNamespace: 'microsoft.insights/components'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          timeAggregation: 'Count'
          skipMetricValidation: false
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'microsoft.insights/components'
    targetResourceRegion: 'uksouth'
    actions: [
      {
        actionGroupId:actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

@description('Set up an email alert')
resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'email-alert'
    enabled: true
    emailReceivers: [
      {
        name: alertEmailRecipientName
        emailAddress: alertEmailRecipientAddress
        useCommonAlertSchema: false
        //status: 'Enabled'
      }
    ]
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

output alertID string = failureNotification.id
output actionGroupID string = actionGroup.id
output applicationInsightsID string = applicationInsights.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
