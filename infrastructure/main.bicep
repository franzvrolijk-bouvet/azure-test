@minLength(3)
@maxLength(24)
param storageAccountName string

param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
    name: storageAccountName
    location: location
    sku: {
        name: 'Standard_LRS'
    }
    kind: 'StorageV2'
    properties: {
        accessTier: 'Hot'
    }
}

output storageAccountName string = storageAccount.name
output storageAccountEndpoint string = storageAccount.properties.primaryEndpoints.blob