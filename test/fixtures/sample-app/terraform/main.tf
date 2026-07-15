# Sample GC cloud workload — Aurora Platform tenant
# Represents a Protected B application on the SSC Landing Zone

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "stfstateprod"
    container_name       = "tfstate"
    key                  = "sample-app.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ── Resource group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "app" {
  name     = "rg-sample-app-prod"
  location = "canadacentral"
  tags = {
    environment = "prod"
    classification = "protected-b"
    owner = "platform-team"
  }
}

# ── Storage account — INTENTIONALLY missing encryption config ─────────────────
# SC-28 FAIL: no customer-managed key, no encryption_at_rest block

resource "azurerm_storage_account" "data" {
  name                     = "stsampleappprod"
  resource_group_name      = azurerm_resource_group.app.name
  location                 = azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  # Missing: customer_managed_key block
  # Missing: infrastructure_encryption_enabled = true
}

# ── Blob container ────────────────────────────────────────────────────────────

resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.data.name
  container_access_type = "private"
}

# ── Key Vault — PASS for SC-12 ────────────────────────────────────────────────

resource "azurerm_key_vault" "app" {
  name                = "kv-sample-app-prod"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  network_acls {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = []
  }
}

data "azurerm_client_config" "current" {}

# ── IAM — broad role assignment — FAIL for AC-6 ──────────────────────────────
# Contributor role (overly broad) assigned to a service principal

resource "azurerm_role_assignment" "app_contributor" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Contributor"  # Too broad — should be a custom minimal role
  principal_id         = "00000000-0000-0000-0000-000000000001"
}

# ── Network security group — PASS for SC-7 ───────────────────────────────────

resource "azurerm_network_security_group" "app" {
  name                = "nsg-sample-app-prod"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  security_rule {
    name                       = "allow-https-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ── Backup — PASS for CP-9 ───────────────────────────────────────────────────

resource "azurerm_recovery_services_vault" "backup" {
  name                = "rsv-sample-app-prod"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "Standard"
  soft_delete_enabled = true
}

resource "azurerm_backup_policy_blob_storage" "data" {
  name               = "backup-policy-blob"
  vault_id           = azurerm_recovery_services_vault.backup.id
  retention_duration = "P30D"
}
