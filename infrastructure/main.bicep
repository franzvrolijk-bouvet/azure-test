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
      {
        tenantId: subscription().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: '51c3e825-55b6-4e8e-ae26-16073ca1de98'
        permissions: {
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

resource storageAccountConnectionString 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  parent: keyVault
  name: 'StorageAccountConnectionString'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
  }
}

resource cosmosDbConnectionString 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  parent: keyVault
  name: 'CosmosDbConnectionString'
  properties: {
    value: 'AccountEndpoint=${dbAccount.properties.documentEndpoint};AccountKey=${dbAccount.listKeys().primaryMasterKey}'
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

resource appServiceConfig 'Microsoft.Web/sites/config@2024-04-01' = {
    parent: appService
    name: 'appsettings'
    properties: {
      KeyVaultUri: keyVault.properties.vaultUri
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
                    value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/StorageAccountConnectionString)'
                }
                {
                    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
                    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
                }
                {
                    name: 'FUNCTIONS_WORKER_RUNTIME'
                    value: 'node'
                }
                {
                  name: 'WEBSITE_NODE_DEFAULT_VERSION'
                  value: '~20'
                }
                {
                  name: 'CosmosDbConnectionString'
                  value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/CosmosDbConnectionString)'
                }
                {
                  name: 'StorageAccountConnectionString'
                  value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/StorageAccountConnectionString)'
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

  resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
    name: '${env}-apim'
    location: resourceGroup().location
    sku: {
      name: 'Developer'
      capacity: 1
    }
    properties: {
      publisherEmail: 'franz.vrolijk@bouvet.no'
      publisherName: 'Franz Vrolijk'
    }
  }
