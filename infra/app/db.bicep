param location string
param tags object
param resourceToken string
param databaseName string
param containerName string

@description('Enables serverless for this account. Defaults to false.')
param enableServerless bool = true

@description('Enables NoSQL vector search for this account. Defaults to false.')
param enableNoSQLVectorSearch bool = false

@description('Enables NoSQL full text search for this account. Defaults to false.')
param enableNoSQLFullTextSearch bool = false

@description('The amount of throughput set. If setThroughput is enabled, defaults to 400.')
param throughput int = 400

@description('Enables throughput setting at this resource level. Defaults to true.')
param setThroughput bool = false

@description('Enables autoscale. If setThroughput is enabled, defaults to false.')
param autoscale bool = true

@description('Whether VNet integration is enabled for Cosmos DB. If true, disables public network access.')
param vnetEnabled bool = false

var publicNetworkAccess = vnetEnabled ? 'Disabled' : 'Enabled'

var options = setThroughput
  ? autoscale
      ? {
          autoscaleSettings: {
            maxThroughput: throughput
          }
        }
      : {
          throughput: throughput
        }
  : {}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'cosmos-${resourceToken}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    disableLocalAuth: true
    publicNetworkAccess: publicNetworkAccess
    capabilities: union(
      (enableServerless)
        ? [
            {
              name: 'EnableServerless'
            }
          ]
        : [],
      (enableNoSQLVectorSearch)
        ? [
            {
              name: 'EnableNoSQLVectorSearch'
            }
          ]
        : [],
      (enableNoSQLFullTextSearch)
        ? [
            {
              name: 'EnableNoSQLFullTextSearch'
            }
          ]
        : []  
    )
  }
}
 
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmosDbAccount
  name: !empty(databaseName) ? databaseName : 'db-${resourceToken}'
  properties: {
    resource: {
      id: !empty(databaseName) ? databaseName : 'db-${resourceToken}'
    }
  }
}
 
resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: cosmosDbDatabase
  name: !empty(containerName) ? containerName : 'container-${resourceToken}'
  properties: {
    options: options
    resource: {
      id: !empty(containerName) ? containerName : 'container-${resourceToken}'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'MultiHash'
        version: 2
      }
      indexingPolicy: {
        automatic: true
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
  }
}
 

resource cosmosDbLeasesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: cosmosDbDatabase
  name: 'leases'
  properties: {
    resource: {
      id: 'leases'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}

output cosmosDbName string = cosmosDbDatabase.name
output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbContainer string = cosmosDbContainer.name
output cosmosDbAccountEndpoint string = cosmosDbAccount.properties.documentEndpoint
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output cosmosDbAccountId string = cosmosDbAccount.id
