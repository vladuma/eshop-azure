param location string
param resourceNamePrefix string
param tags object


// Microsoft.Web/sites/config
param allowedOrigins array = []
param alwaysOn bool = false
param appCommandLine string = ''
param clientAffinityEnabled bool = false
param functionAppScaleLimit int = -1
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param use32BitWorkerProcess bool = false
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = ''

resource orderItemsReserver 'Microsoft.Web/sites@2022-09-01' = {
  name: '${resourceNamePrefix}-func'
  location: location
  tags: tags
  kind: 'functionApp'
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: true
    siteConfig: {
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
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'

        }
      ]
    }
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
  }
}
resource httpTrigger 'Microsoft.Web/sites/functions@2022-09-01' = {
  parent: orderItemsReserver
  name: '${resourceNamePrefix}_HttpTrigger'
  properties: {
    language: 'dotnet'

    config: {
      bindings: [
        {
          direction: 'in'
          type: 'httpTrigger'
          name: 'req'
        }
        {
          direction: 'out'
          type: 'http'
          name: 'res'
        }
      ]
    }
  }
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: toLower('OrderItemsStorage2603')
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${resourceNamePrefix}-asp'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

output functionBaseUrl string = 'https://${orderItemsReserver.properties.defaultHostName}'
