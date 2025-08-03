## Create a random string
## 
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

## Create a storage account for Terraform state
##
resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstate${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"

  tags = {
    environment = "development"
    project     = "aifoundry"
  }
}

## Create container for Terraform state
##
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

## Create user-assigned managed identity
##
resource "azurerm_user_assigned_identity" "project_identity" {
  name                = "id-aifoundry${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location           = var.location

  tags = {
    environment = "development"
    project     = "aifoundry"
  }
}

## Create a resource group for the resources to be stored in
##
resource "azurerm_resource_group" "rg" {
  name     = "rg-aifoundry${random_string.unique.result}"
  location = var.location
}

########## Create AI Foundry resource
##########

## Create the AI Foundry resource
##
resource "azapi_resource" "ai_foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2023-05-01"
  name                      = "aifoundry${random_string.unique.result}"
  parent_id                 = azurerm_resource_group.rg.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    identity = {
      type = "UserAssigned"
      userAssignedIdentities = {
        "${azurerm_user_assigned_identity.project_identity.id}" = {}
      }
    }
    properties = {
      disableLocalAuth = false
      allowProjectManagement = true
      customSubDomainName = "aifoundry${random_string.unique.result}"
    }
  }
}
  


## Create a deployment for OpenAI's GPT-4o in the AI Foundry resource
##
resource "azurerm_cognitive_deployment" "aifoundry_deployment_gpt_4o" {
  depends_on = [
    azapi_resource.ai_foundry
  ]

  name                 = "gpt-4o"
  cognitive_account_id = azapi_resource.ai_foundry.id

  sku {
    name     = "Standard"
    capacity = 1
  }

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }
}

## Create AI Foundry project
##
resource "azapi_resource" "ai_foundry_project" {
  type                      = "Microsoft.CognitiveServices/accounts/projects@2023-10-01-preview"
  name                      = "project${random_string.unique.result}"
  parent_id                 = azapi_resource.ai_foundry.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    properties = {
      displayName = "project"
      description = "My first project"
      settings = {
        defaultDeploymentName = "gpt-4o"
      }
    }
  }
}
## Create Azure AI Search service
##
resource "azurerm_search_service" "search" {
  name                = "search${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                = "free"
  replica_count      = 1
  partition_count    = 1

  tags = {
    environment = "development"
    project     = "aifoundry"
  }
}
