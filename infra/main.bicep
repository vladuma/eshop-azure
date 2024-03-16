targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@minLength(1)
@description('Secondary location for all resources')
param secondaryLocation string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param resourceGroupName string = ''
param webServiceName string = ''
param apiServiceName string = ''
param catalogDatabaseName string = 'catalogDatabase'
param catalogDatabaseServerName string = ''
param identityDatabaseName string = 'identityDatabase'
param identityDatabaseServerName string = ''
param appServicePlanName string = ''
param apiServicePlanName string = ''
param keyVaultName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

@secure()
@description('Application user password')
param appUserPassword string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}-test'
  location: location
  tags: tags
}

// The application frontend
module web './core/host/appservice.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'web' })
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
    }
  }
}

module secondaryWeb './core/host/appservice.bicep' = {
  name: 'secondaryWeb'
  scope: rg
  params: {
    name: !empty(webServiceName) ? '${webServiceName}-secondary' : '${abbrs.webSitesAppService}web-secondary-${resourceToken}'
    location: secondaryLocation
    appServicePlanId: secondaryAppServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'secondaryWeb' })
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
    }
  }
}

module api './core/host/apiservice.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? '${apiServiceName}' : '${abbrs.webSitesAppService}api-${resourceToken}'
    location: location
    appServicePlanId: apiServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    tags: union(tags, { 'azd-service-name': 'api' })
    appSettings: {
      AZURE_SQL_CATALOG_CONNECTION_STRING_KEY: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
      AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
    }
  }
}

module trafficManagerProfile './core/modules/trafficmanager.bicep' = {
  name: 'trafficManagerProfile'
  scope: rg
  params: {
    location: 'global'
    tags: tags
    profileName: '${abbrs.networkTrafficManagerProfiles}esow-profile-${resourceToken}'
    endpoint1Name: web.outputs.name
    endpoint1Priority: 1
    endpoint2Name: secondaryWeb.outputs.name
    endpoint2Priority: 2
    location1: location
    location2: secondaryLocation
  }
}

module apiKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access-eShop'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: web.outputs.identityPrincipalId
    secondaryPrincipalId: secondaryWeb.outputs.identityPrincipalId
  }
}

// The application database: Catalog
module catalogDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-catalog'
  scope: rg
  params: {
    name: !empty(catalogDatabaseServerName) ? catalogDatabaseServerName : '${abbrs.sqlServers}catalog-${resourceToken}'
    databaseName: catalogDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-CATALOG-CONNECTION-STRING'
  }
}

// The application database: Identity
module identityDb './core/database/sqlserver/sqlserver.bicep' = {
  name: 'sql-identity'
  scope: rg
  params: {
    name: !empty(identityDatabaseServerName) ? identityDatabaseServerName : '${abbrs.sqlServers}identity-${resourceToken}'
    databaseName: identityDatabaseName
    location: location
    tags: tags
    sqlAdminPassword: sqlAdminPassword
    appUserPassword: appUserPassword
    keyVaultName: keyVault.outputs.name
    connectionStringKey: 'AZURE-SQL-IDENTITY-CONNECTION-STRING'
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault-eShop'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// Create an API Service Plan to group applications under the same payment plan and SKU
module apiServicePlan './core/host/appserviceplan.bicep' = {
  name: 'apiserviceplan'
  scope: rg
  params: {
    name: !empty(apiServicePlanName) ? apiServicePlanName : '${abbrs.webServerFarms}api-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'S1'
    }
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'S1'
    }
  }
}

// Create a secondary App Service Plan to group applications under the same payment plan and SKU
module secondaryAppServicePlan './core/host/secondaryappserviceplan.bicep' = {
  name: 'secondaryappserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? '${appServicePlanName}-secondary' : '${abbrs.webServerFarms}${resourceToken}-secondary'
    location: secondaryLocation
    tags: tags
    sku: {
      name: 'S1'
    }
  }
}

// Data outputs
output AZURE_SQL_CATALOG_CONNECTION_STRING_KEY string = catalogDb.outputs.connectionStringKey
output AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY string = identityDb.outputs.connectionStringKey
output AZURE_SQL_CATALOG_DATABASE_NAME string = catalogDb.outputs.databaseName
output AZURE_SQL_IDENTITY_DATABASE_NAME string = identityDb.outputs.databaseName

// App outputs
output AZURE_LOCATION string = location
output AZURE_LOCATION_S string = secondaryLocation
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
