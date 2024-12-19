@minLength(3)
@maxLength(24)
param storageAccountName string
param appServicePlanName string
param appServiceName string

param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
    name: storageAccountName
    location: location
    sku: {
        name: 'Standard_LRS'
    }
    kind: 'StorageV2'
    properties: {
        accessTier: 'Hot'
        supportsHttpsTrafficOnly: true
        defaultToOAuthAuthentication: true
    }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
    name: appServicePlanName
    location: location
    sku: {
        name: 'F1'
        tier: 'Free'
    }
    properties: {}
}

resource appService 'Microsoft.Web/sites@2024-04-01' = {
    name: appServiceName
    location: location
    properties: {
        serverFarmId: appServicePlan.id
    }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
    name: '${appServiceName}-functionApp'
    location: location
    kind: 'functionapp'
    identity: {
        type: 'SystemAssigned'
    }
    properties: {
        siteConfig: {
            appSettings: [
                {
                    name: 'AzureWebJobsStorage'
                    value: storageAccount.properties.primaryEndpoints.blob
                }
                {
                    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
                    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
                }
                {
                    name: 'FUNCTIONS_WORKER_RUNTIME'
                    value: 'node'
                }
            ]
        }
        httpsOnly: true
    }
}

resource dbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
    name: '${storageAccountName}-cosmosdb'
    location: location
    properties: {
      enableFreeTier: true
      databaseAccountOfferType: 'Standard'
      consistencyPolicy: {
        defaultConsistencyLevel: 'Session'
      }
      locations: [
        {
          locationName: location
        }
      ]
    }
  }
  
  resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
    parent: dbAccount
    name: 'db'
    properties: {
      resource: {
        id: 'db'
      }
      options: {
        throughput: 1000
      }
    }
  }
  
  resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
    parent: database
    name: 'dbContainer'
    properties: {
      resource: {
        id: 'dbContainer'
        partitionKey: {
          paths: [
            '/id'
          ]
          kind: 'Hash'
        }
        indexingPolicy: {
          indexingMode: 'consistent'
          includedPaths: [
            {
              path: '/*'
            }
          ]
          excludedPaths: [
            {
              path: '/_etag/?'
            }
          ]
        }
      }
    }
  }
