dependencies {
  paths = [
    format("%s/../../bootstrap/az-launchpad-bootstrap-helper", replace(get_original_terragrunt_dir(), "\\", "/")),
    format("%s/../../launchpad/ado-project", replace(get_original_terragrunt_dir(), "\\", "/")),
    format("%s/../ado-repo-sync-configuration", replace(get_original_terragrunt_dir(), "\\", "/"))
  ]
}

dependency "l0-az-lp-backend" {
  config_path = format("%s/../../launchpad/az-launchpad-backend", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    resource_group_launchpad = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg-lp"
      name     = "mock-rg-lp"
      location = "westeurope"
    }
    resource_group_tf_backend = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg-be"
      name     = "mock-rg-be"
      location = "westeurope"
    }
    virtual_networks = {
      l0-launchpad-main = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
        name                = "mock-vnet"
        resource_group_name = "mock-rg"
        location            = "westeurope"
        address_space = [
          "192.0.2.0/24"
        ]
      }
    }
    virtual_network_subnets = {
      l0-launchpad-main-default = {
        id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name                 = "mock"
        resource_group_name  = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
    storage_accounts = {
      l0 = {
        ecp_level           = "l0"
        subscription_id     = "00000000-0000-0000-0000-000000000000"
        resource_group_name = "mock-rg"
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal0"
        name                = "mocksal0"
        location            = "westeurope"
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
        ecp_level           = "l1"
        subscription_id     = "00000000-0000-0000-0000-000000000000"
        resource_group_name = "mock-rg"
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal1"
        name                = "mocksal1"
        location            = "westeurope"
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
        ecp_level           = "l2"
        subscription_id     = "00000000-0000-0000-0000-000000000000"
        resource_group_name = "mock-rg"
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal2"
        name                = "mocksal2"
        location            = "westeurope"
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
      l3 = {
        ecp_level           = "l3"
        subscription_id     = "00000000-0000-0000-0000-000000000000"
        resource_group_name = "mock-rg"
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal3"
        name                = "mocksal3"
        location            = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal3.blob.core.windows.net"
          private_ip_address = "192.0.2.7"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
    }
    ecp_environment_name                           = "mock"
    ecp_azure_devops_automation_repository_name    = "mock-repo-automation"
    ecp_azure_devops_configuration_repository_name = "mock-repo-configuration"
    ecp_configuration_repo_deployment_root_path    = "mock/deployment/root/path"
    azuredevops_organization_name                  = "mock"
    ecp_automation_terragrunt_version              = "0.0.0"
    ecp_automation_terraform_version               = "0.0.0"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "deep_map_only"
}

locals {
  library_path_shared = format("%s/lib/ecp-lib", replace(get_repo_root(), "\\", "/"))
  library_path_unit   = "${replace(get_terragrunt_dir(), "\\", "/")}/lib"

  automation_path = format("%s/lib/ecp-automation", replace(get_repo_root(), "\\", "/"))

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = replace(coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  ), "\\", "/")

  # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_LEVEL0_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL0_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL0_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL0_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(
    try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

  backend_type = local.backend_config_present ? "azurerm" : try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true ? "azurerm" : "local", "local")
  backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_LEVEL0_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_LEVEL0_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_LEVEL0_NAME")
    container_name       = get_env("ECP_TG_BACKEND_LEVEL0_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : local.backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"

    # ECP fully provisions the backend during initial run with backend/* modules
    #     and also handles state migration
    skip_resource_group_creation  = true
    skip_storage_account_creation = true
    skip_container_creation       = true
    skip_versioning               = true
    } : {
    path = local.bootstrap_local_backend_path
  }

  ################# tags #################
  unit_common_azure_tags = {
    # "_ecpTgUnitCommon" = format("%s/unit-common.hcl", replace(get_parent_terragrunt_dir(), "\\", "/"))
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
  backend = local.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config       = local.backend_config
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
      "-NoLogo", "-NoProfile", "-NonInteractive",
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
      # "destroy",  # child of az-launchpad-backend: no need to migrate back to local state during destroy
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
      "-NoLogo", "-NoProfile", "-NonInteractive",
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

  local_git_submodule_path = local.automation_path
  filter_git_subfolders    = false

  ecp_azure_devops_repository_name = dependency.l0-az-lp-backend.outputs.ecp_azure_devops_automation_repository_name

  template_replacements = {
    "ecp_environment_name_replacement" = {
      directory_patterns = [
        "**/pipelines-ado"
      ]
      name_replacements = {
        "pipelines-ado" = "pipelines-${dependency.l0-az-lp-backend.outputs.ecp_environment_name}-ado"
      }
      file_patterns = [
        "**/ecp-tg-deploy-landing-zone.yaml",
        "**/ecp-tg-deploy-platform-infrastructure.yaml",
        "**/ecp-tg-deploy-platform-infrastructure-singlestack.yaml",
        "**/ecp-debug-adopool-analysis.yaml"
      ]
      content_replacements = {
        "<ecp_environment_name>"   = "${dependency.l0-az-lp-backend.outputs.ecp_environment_name}"
        "<ecp_terragrunt_version>" = "${dependency.l0-az-lp-backend.outputs.ecp_automation_terragrunt_version}"
        "<ecp_terraform_version>"  = "${dependency.l0-az-lp-backend.outputs.ecp_automation_terraform_version}"
      }
    }
  }
}
