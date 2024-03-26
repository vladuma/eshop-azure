param location string
param resourceNamePrefix string
param tags object

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: toLower(resourceNamePrefix)
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${toLower(resourceNamePrefix)}/default/orderitems'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    storageAccount
  ]
}

output storageAccountName string = storageAccount.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
