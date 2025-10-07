dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
  mock_outputs = {
    actor_identity            = {
      client_id                 = "00000000-0000-0000-0000-000000000000"
      display_name              = "noidentity"
      is_ecp_launchpad_identity = false
      object_id                 = "00000000-0000-0000-0000-000000000000"
      tenant_id                 = "00000000-0000-0000-0000-000000000000"
      type                      = "ManagedIdentity"
      user_principal_name       = "No Identity"
    }
     actor_network_information = {
       ecp_launchpad_network_cidr       = "192.0.2.0/25"
       is_local_ip_within_ecp_launchpad = false
       local_ip                         = "192.168.0.1"
       public_ip                        = "0.0.0.0"
     }
    backend_resource_group    = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      location        = "westeurope"
      name            = "mock-rg"
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
    backend_storage_accounts = {
      l0 = {
        name                            = "mocksal0"
        id                                             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal0"
        resource_group_name             = "mock-rg"
        location                                       = "westeurope"
        subscription_id                 = "00000000-0000-0000-0000-000000000000"
        tf_backend_container            = "tfstate"
        ecp_resource_exists             = false
        ecp_terraform_backend                          = "local"
        ecp_terraform_backend_apply_timestamp = ""
        ecp_terraform_backend_changed_since_last_apply = false
      }
      l1 = {
        name                            = "mocksal1"
        id                                             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal1"
        resource_group_name             = "mock-rg"
        location                                       = "westeurope"
        subscription_id                 = "00000000-0000-0000-0000-000000000000"
        tf_backend_container            = "tfstate"
        ecp_resource_exists             = false
        ecp_terraform_backend                          = "local"
        ecp_terraform_backend_apply_timestamp = ""
        ecp_terraform_backend_changed_since_last_apply = false
      }
      l2 = {
        name                            = "mocksal2"
        id                                             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal2"
        resource_group_name             = "mock-rg"
        location                                       = "westeurope"
        subscription_id                 = "00000000-0000-0000-0000-000000000000"
        tf_backend_container            = "tfstate"
        ecp_resource_exists             = false
        ecp_terraform_backend                          = "local"
        ecp_terraform_backend_apply_timestamp = ""
        ecp_terraform_backend_changed_since_last_apply = false
      }
    }
  }
}

dependency "l0-lp-az-lp-main" {
  config_path = format("%s/../az-launchpad-main", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "westeurope"
    }
  }
}

dependency "l0-lp-az-lp-net" {
  config_path = format("%s/../az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
    virtual_networks = {
      l0-launchpad-main = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
        name = "mock-vnet"
        resource_group_name = "mock-rg"
        location = "westeurope"
        address_space = [
          "192.0.2.0/24"
        ]
      }
    }
    virtual_network_subnets = {
      l0-launchpad-main-default = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name = "mock"
        resource_group_name = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
  }
}

locals {
  ecp_deployment_unit = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-backend"

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = get_env("TG_DOWNLOAD_DIR", trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-Command", "[System.IO.Path]::GetTempPath()")))
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true  && get_terraform_command() != "destroy" ? "azurerm" : "local", "local")
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

################# tags #################
  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
 backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.bootstrap_backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : {
    path = local.bootstrap_local_backend_path
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {
  
  # before destroying the remote state:
  #     copy states of units this one depends on from remote to local state files
  #     ---> but only if remote state actually was deployed and implemented already
  #          (local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists)
  before_hook "backup-terraformState-dependentUnits" {
    commands     = [
      "destroy"  # during destroy the remote state will be destroyed; so we need to fail back all units that depend on this one to local state
      ]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

$dependentUnits = @(
    "az-launchpad-bootstrap-helper",
    "az-launchpad-main",
    "az-launchpad-network",
    "az-launchpad-backend"
)

if ("true" -eq "${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists, "false")}") {
  Write-Output "INFO: backup remote states of dependent units to local state files" 
  foreach ($unit in $dependentUnits) {
    $unitLocalStateFile = "${local.bootstrap_helper_folder}/$($unit).tfstate"
    Write-Output "     downloading $($unit).tfstate to $unitLocalStateFile"
    az storage blob download --account-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")} --container-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container, "unknown container")} --file "$unitLocalStateFile" --name "$($unit).tfstate" --overwrite --auth-mode "login" --no-progress | Out-Null
  }
  Write-Output "     reconfigure unit to work with local state now"  
  terraform init -reconfigure | Out-Null
}
else {
  Write-Output "INFO: remote backend not deployed yet; skipping backup of dependent units' states"
}
SCRIPT
    ]
    run_on_error = false
  }

  before_hook "Copy-TerraformStateToRemote" {
     commands     = [
      "apply",
      # "destroy",  # during destroy the remote state should no longer be present
      # "force-unlock",
      "import",
      "init", # on initial run, no outputs will be available, yet
      "output",
      "plan", 
      "refresh",
      "state",
      "taint",
      "untaint",
      "validate"
      ]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
Write-Output "INFO: bootstrap_backend_type: '${local.bootstrap_backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
    if ("azurerm" -eq "${local.bootstrap_backend_type}") {
        if (Test-Path "${local.bootstrap_local_backend_path}") {
            Write-Output "      remote backend changed from 'local' to 'azurerm'; copying local state to remote now..."
            Write-Output "      uploading '${local.bootstrap_local_backend_path}' to '${basename(path_relative_to_include())}.tfstate' on ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")}'"  
            az storage blob upload --account-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")} --container-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container, "unknown container")} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress | Out-Null
            terraform init -reconfigure | Out-Null
        }
        else {
            Write-Output "      local state file '${local.bootstrap_local_backend_path}' dos not exist; skipping upload to remote backend"
        }
    }
    else {
        Write-Output "      remote backend changed to 'local'; no action required as local state is already in place"
        az storage blob download --account-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")} --container-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container, "unknown container")} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress | Out-Null
        terraform init -reconfigure | Out-Null
    }
}
else {
    Write-Output "INFO: backend has not changed; no action required"
}
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
   
  virtual_subnet_id = dependency.l0-lp-az-lp-net.outputs.virtual_network_subnets.l0-launchpad-main-default.id

  # if running from outside ECP network, storage account must allow (temporary)public network access
  storage_account_public_network_access_enabled = dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad == true ? false : true
}
