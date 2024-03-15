@minLength(1)
@description('The location for the Traffic Manager. Must be "global".')
param location string

param tags object

@minLength(1)
@description('The name of the Traffic Manager profile.')
param profileName string

@minLength(1)
@description('The name of the first endpoint.')
param endpoint1Name string

@minLength(1)
@description('Location 1.')
param location1 string

@description('The priority of the first endpoint. Lower values are preferred.')
param endpoint1Priority int


@minLength(1)
@description('The name of the second endpoint.')
param endpoint2Name string

@description('The priority of the second endpoint. Lower values are preferred.')
param endpoint2Priority int

@minLength(1)
@description('Location 2.')
param location2 string



resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2022-04-01'= {
  name: profileName
  location: location
  tags: tags
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: profileName
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      expectedStatusCodeRanges: [
        {
          min: 200
          max: 202
        }
        {
          min: 301
          max: 302
        }
      ]
    }
    endpoints: [
      {
        name: endpoint1Name
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          priority: endpoint1Priority
          target: '${endpoint1Name}.azurewebsites.net'
          endpointLocation: location1
        }
      }
      {
        name: endpoint2Name
        type: 'Microsoft.Network/trafficManagerProfiles/externalEndpoints'
        properties: {
          endpointStatus: 'Enabled'
          priority: endpoint2Priority
          target: '${endpoint2Name}.azurewebsites.net'
          endpointLocation: location2
        }
      }
    ]
  }
}

output name string = trafficManagerProfile.name
output resourceGroupName string = resourceGroup().name
output resourceId string = trafficManagerProfile.id
