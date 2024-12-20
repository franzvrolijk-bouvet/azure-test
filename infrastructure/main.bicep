@minLength(3)
@maxLength(10)
param env string

param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
    name: '${env}storage'
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

resource keyVault 'Microsoft.KeyVault/vaults@2018-02-14' = {
  name: '${env}-keyvault'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2018-02-14' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.identity.principalId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
    name: '${env}-appServicePlan'
    location: location
    sku: {
        name: 'F1'
        tier: 'Free'
    }
    properties: {}
}

resource appService 'Microsoft.Web/sites@2024-04-01' = {
    name: '${env}-appService'
    location: location
    properties: {
        serverFarmId: appServicePlan.id
    }
    identity: {
        type: 'SystemAssigned'
    }
}

resource functionPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
    name: '${env}-functionPlan'
    location: location
    sku: {
        name: 'Y1'
        tier: 'Dynamic'
    }
    properties: {}
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
    name: '${env}-functionApp'
    location: location
    kind: 'functionapp'
    identity: {
        type: 'SystemAssigned'
    }
    properties: {
        serverFarmId: functionPlan.id
        siteConfig: {
            appSettings: [
                {
                    name: 'AzureWebJobsStorage'
                    value: storageAccount.properties.primaryEndpoints.blob
                }
                {
                    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
                    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
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
    name: '${env}dbaccount'
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

  
resource cosmosDbSqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-11-15' = {
  name: guid(dbAccount.id, 'CosmosDBAccountReaderRole')
  parent: dbAccount
  properties: {
    roleName: 'CosmosDBAccountReaderRole'
    type: 'CustomRole'
    assignableScopes: [
      dbAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
        ]
      }
    ]
  }
}

resource cosmosDbSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(dbAccount.id, appService.id, 'CosmosDBAccountReaderRoleAssignment')
  parent: dbAccount
  properties: {
    roleDefinitionId: cosmosDbSqlRoleDefinition.id
    principalId: appService.identity.principalId
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
    name: 'container'
    properties: {
      resource: {
        id: 'container'
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
