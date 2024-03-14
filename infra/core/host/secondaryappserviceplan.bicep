param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
param reserved bool = true
param sku object


resource secondaryAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${name}-secondary'
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
  }
}

output id string = secondaryAppServicePlan.id
