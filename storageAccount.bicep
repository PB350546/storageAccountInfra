// This is Bicep template for creation of storage Account

@description('The object parameter for storage account configuration properties.')
param storageConfig  object = {}

@description('Resource Group Tags for inheritance.')
param rgTags object = {}

@description('The storage account location.')
param location string = resourceGroup().location

// variables for string interpolation or Logical expressions for condition validation.
var containers= storageConfig.containers
var tags= (empty(storageConfig.tags) ? rgTags : union(storageConfig.tags, rgTags))
var publicNetworkAccess= storageConfig.publicNetworkAccess ?? 'Enabled'
var minimumTlsVersion= storageConfig.minimumTlsVersion ?? 'TLS1_2'
var defaultAction= storageConfig.defaultAction ?? 'Allow'
var bypass= storageConfig.bypass ?? 'AzureServices'
var virtualNetworkRules= storageConfig.virtualNetworkRules ?? []
var ipRules= storageConfig.ipRules ?? []

// Based on user inputs validating identity conditions for storage account.
var identity= !(empty(storageConfig.identity)) ? identityTrue : identityFalse
var identityTrue= {
  type: storageConfig.identity.type
  userAssignedIdentities: storageConfig.identity.userAssignedIdentities
}
var identityFalse= {
  type: 'None'
  userAssignedIdentities: {}
}

//Based on user inputs for encryption identity type validating Customer-managed keys encryption.
var encryption= storageConfig.cmk.isUserEncryption ? customerIdentityEncryption : systemIdentityEncryption
var keyvaultproperties= {
      keyname: storageConfig.cmk.keyName
      keyversion: storageConfig.cmk.keyVersion
      keyvaulturi: storageConfig.cmk.keyVaultUri
    }
var services= {
    blob: {
      enabled: true
      keyType: 'Account'
  }
}
var customerIdentityEncryption= {
  services : services
  keySource: 'Microsoft.Keyvault'
  keyvaultproperties: keyvaultproperties
  identity: {
    userAssignedIdentity: storageConfig.cmk.userAssignedIdentity
  }
}
var systemIdentityEncryption= {
  services : services
  keySource: 'Microsoft.Keyvault'
  keyvaultproperties: keyvaultproperties
  identity: {
    systemAssignedIdentity: 'Enabled' 
    // This property is not available in documentation so not completely sure about it.
    // Document refered : https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?pivots=deployment-language-bicep
  }
}

// Resource defination block to deploy Storage account Infrastructure
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageConfig.storageAccountName
  location: location
  sku: {
    name: storageConfig.storageAccountType
  }
  kind: 'StorageV2'
  tags: tags
  identity: identity
  properties: {
    publicNetworkAccess: publicNetworkAccess
    minimumTlsVersion: minimumTlsVersion
    encryption: encryption
    networkAcls: {
      defaultAction: defaultAction
      bypass: bypass
      virtualNetworkRules: virtualNetworkRules
      ipRules: ipRules
    }
  }
}

// Resource defination block for creation of multiple containers under default blob.
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource containersCreate 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in containers: {      // looping through containers specified in param file
  name: '${container.name}'
}]

// Resource defination block for creation of diagnostic settings for storage account.
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (storageConfig.storageDiagnosticsSettings.blobDiagnostics){
  name: 'diagSettings'
  scope: blobServices
  properties: {
    storageAccountId: storageAccount.id
    workspaceId: storageConfig.storageDiagnosticsSettings.logAnalyticsWorkspaceId
    eventHubAuthorizationRuleId: storageConfig.storageDiagnosticsSettings.eventHubAuthorizationRuleId
    eventHubName: storageConfig.storageDiagnosticsSettings.eventHubName
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

// Output block to send identity id based on condition as an deployment output.
output systemAssignedPrincipalId string = storageConfig.identity.type == 'SystemAssigned' || storageConfig.identity.type == 'SystemAssigned,UserAssigned' ? storageAccount.identity.principalId : 'None'
