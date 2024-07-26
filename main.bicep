// Bicep template for creation of Resource Group and a storage Acoount
// ******************************************************** Assumptions ********************************************************
// . Using Parameter file as User Input file for Bicep Template.
// . Other Possibility : We can also use Pipeline Parameters/Variables and use them as override parameters during Deployment.
// ******************************************************** Assumptions ********************************************************

// Target scope for Creation of resource Group
targetScope='subscription'

@description('Parameter containing all required properties of Resource Group and Storage Account')
param resourceGroup object

// Resource defination to create the Resource Group
resource resourceGroupCreate 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroup.resourceGroupName
  location: resourceGroup.resourceGroupLocation
  tags: resourceGroup.tags
}

// Resource module for creation of Storage account under ResourceGroup Scope
module storageAccount 'storageAccount.bicep' = {
  name: 'storageAccount'
  scope: resourceGroupCreate
  params: {
    storageConfig: resourceGroup.storageAccount
    rgTags : resourceGroup.tags
  }
}

// Output SystemAssignedIdentity ID
output systemAssignedPrincipalId string = storageAccount.outputs.systemAssignedPrincipalId
