dependencies {
  paths = [
    format("%s/../../bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
  ]
}

dependency "l0-lp-az-lp-backend" {
  config_path = format("%s/../az-launchpad-backend", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    storage_accounts = {
      l0 = {
        ecp_level = "l0"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal0"
        name      = "mocksal0"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal0.blob.core.windows.net"
          private_ip_address = "192.0.2.4"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
      l1 = {
        ecp_level = "l1"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal1"
        name      = "mocksal1"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal1.blob.core.windows.net"
          private_ip_address = "192.0.2.5"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
      l2 = {
        ecp_level = "l2"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal2"
        name      = "mocksal2"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal2.blob.core.windows.net"
          private_ip_address = "192.0.2.6"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l0-lp-az-lp-main" {
  config_path = format("%s/../az-launchpad-main", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    ecp_environment_name                           = "mock-environment"
    ecp_azure_devops_automation_repository_name    = "mock.automation"
    ecp_azure_devops_configuration_repository_name = "mock.configuration"
    azuredevops_organization_name                  = "mock-ado-org"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_unit             = "ado-project"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-project"

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )

  # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_NAME", "") != "",
    get_env("ECP_TG_BACKEND_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(
    try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

  backend_type         = local.backend_config_present ? "azurerm" : try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true && get_terraform_command() != "destroy" ? "azurerm" : "local", "local")
  backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_NAME")
    container_name       = get_env("ECP_TG_BACKEND_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : local.backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    path = local.bootstrap_local_backend_path
  }

  ################# tags #################
  unit_common_azure_tags = {
    # "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
  backend = local.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.backend_config
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {

  before_hook "reconfigure-backend" {
    commands = [
      "init",
      # "plan",
      # "apply",
      # "destroy"
    ]
    execute = [
      "pwsh",
      "-Command",
      <<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

Write-Output "     running 'terraform init -reconfigure'"
terraform init -reconfigure | Out-Null
SCRIPT
    ]
    run_on_error = false
  }

  before_hook "Copy-TerraformStateToRemote" {
    commands = [
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
    execute = [
      "pwsh",
      "-Command",
      <<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
Write-Output "INFO: backend_type: '${local.backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
    if ("azurerm" -eq "${local.backend_type}") {
        if (Test-Path "${local.bootstrap_local_backend_path}") {
            Write-Output "      remote backend changed from 'local' to 'azurerm'; copying local state to remote now..."
            Write-Output "      uploading '${local.bootstrap_local_backend_path}' to '${basename(path_relative_to_include())}.tfstate' on ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")}'"  
            $uploadResult = az storage blob upload --account-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")} --container-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container, "unknown container")} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Output "      state file uploaded successfully to remote backend"
                terraform init -migrate-state | Out-Null
                Write-Output "      removing local state file '${local.bootstrap_local_backend_path}'"
                Move-Item -Path "${local.bootstrap_local_backend_path}" -Destination "${local.bootstrap_local_backend_path}.backup" -Force -ErrorAction SilentlyContinue
            } else {
                Write-Error "      failed to upload state file to remote backend. Error: $uploadResult"
                throw "State file upload failed with exit code: $LASTEXITCODE"
            }
        }
        else {
            Write-Output "      local state file '${local.bootstrap_local_backend_path}' does not exist; skipping upload to remote backend"
        }
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

  ecp_azure_devops_repository_names = distinct(compact([
    dependency.l0-lp-az-lp-main.outputs.ecp_azure_devops_automation_repository_name,
    dependency.l0-lp-az-lp-main.outputs.ecp_azure_devops_configuration_repository_name
  ]))
}
