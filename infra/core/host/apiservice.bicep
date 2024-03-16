param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Properties
param applicationInsightsName string = ''
param appServicePlanId string
param keyVaultName string = ''
param managedIdentity bool = !empty(keyVaultName)

// param autoscaleRules array = [
//   {
//     metricTrigger: {
//       metricName: 'CpuPercentage'
//       metricNamespace: ''
//       metricResourceUri: resourceId('Microsoft.Web/serverFarms', last(split(appServicePlanId, '/')))
//       timeGrain: 'PT1M'
//       statistic: 'Average'
//       timeWindow: 'PT10M'
//       timeAggregation: 'Average'
//       operator: 'GreaterThan'
//       threshold: 70
//     }
//     scaleAction: {
//       direction: 'Increase'
//       type: 'ChangeCount'
//       value: '1'
//       cooldown: 'PT10M'
//     }
//   }
//   {
//     metricTrigger: {
//       metricName: 'CpuPercentage'
//       metricNamespace: ''
//       metricResourceUri: resourceId('Microsoft.Web/serverFarms', last(split(appServicePlanId, '/')))
//       timeGrain: 'PT1M'
//       statistic: 'Average'
//       timeWindow: 'PT10M'
//       timeAggregation: 'Average'
//       operator: 'LessThan'
//       threshold: 30
//     }
//     scaleAction: {
//       direction: 'Decrease'
//       type: 'ChangeCount'
//       value: '1'
//       cooldown: 'PT10M'
//     }
//   }
// ]

// Runtime Properties
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'
param runtimeVersion string

// Microsoft.Web/sites Properties
param kind string = 'app,linux'

// Microsoft.Web/sites/config
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param appSettings object = {}
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param linuxFxVersion string = runtimeNameAndVersion
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param scmDoBuildDuringDeployment bool = false
param use32BitWorkerProcess bool = false
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = ''

resource apiService 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      ftpsState: ftpsState
      minTlsVersion: '1.2'
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
    }
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
  }

  identity: { type: managedIdentity ? 'SystemAssigned' : 'None' }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(appSettings,
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: string(scmDoBuildDuringDeployment)
        ENABLE_ORYX_BUILD: string(enableOryxBuild)
      },
      !empty(applicationInsightsName) ? { APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString } : {},
      !empty(keyVaultName) ? { AZURE_KEY_VAULT_ENDPOINT: keyVault.properties.vaultUri } : {})
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
    dependsOn: [
      configAppSettings
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (!(empty(keyVaultName))) {
  name: keyVaultName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

// resource autoscaleSettings 'Microsoft.Insights/autoscalesettings@2015-04-01' = if (!empty(autoscaleRules)) {
//   name: '${name}-autoscale'
//   location: location
//   properties: {
//     profiles: [
//       {
//         name: 'Default'
//         capacity: {
//           minimum: '1'
//           maximum: '10'
//           default: '1'
//         }
//         rules: autoscaleRules
//       }
//     ]
//     targetResourceUri: resourceId('Microsoft.Web/serverFarms', last(split(appServicePlanId, '/')))
//   }
// }

output identityPrincipalId string = managedIdentity ? apiService.identity.principalId : ''
output name string = apiService.name
output uri string = 'https://${apiService.properties.defaultHostName}'
