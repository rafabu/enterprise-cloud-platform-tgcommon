dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L0", "") == "" || get_env("ECP_TF_BACKEND_STORAGE_AZURE_L1", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", replace(get_original_terragrunt_dir(), "\\", "/"))
    ] : [],
    [
      format("%s/../../ecproot/az-platform-subscriptions", replace(get_original_terragrunt_dir(), "\\", "/"))
    ]
  )))
}

dependency "l0-az-lp-backend" {
  config_path = format("%s/../../../level0/launchpad/az-launchpad-backend", replace(get_original_terragrunt_dir(), "\\", "/"))
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


dependency "az-ecp-parent" {
  config_path = format("%s/../../ecproot/az-ecp-parent", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    parent_management_group_name = "mock-mg"
    parent_management_group_id   = "/providers/Microsoft.Management/managementGroups/mock-mg"
    role_group_contributor_name  = "mock-role-group-contributor"
    role_group_contributor_id    = "00000000-0000-0000-0000-000000000000"
    role_group_reader_name       = "mock-role-group-reader"
    role_group_reader_id         = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "deep_map_only"
}

locals {
  ################# terragrunt specifics #################
  TG_DOWNLOAD_DIR = replace(coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  ), "\\", "/")

  # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_LEVEL1_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(
    try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )

  bootstrap_backend_type         = "azurerm"
  bootstrap_backend_type_changed = false

  backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_LEVEL1_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_LEVEL1_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_LEVEL1_NAME")
    container_name       = get_env("ECP_TG_BACKEND_LEVEL1_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l1"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l1"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l1"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l1"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"

    # ECP fully provisions the backend during initial run with backend/* modules
    #     and also handles state migration
    skip_resource_group_creation  = true
    skip_storage_account_creation = true
    skip_container_creation       = true
    skip_versioning               = true
  }

  ################# tags #################
  unit_common_azure_tags = {
    # "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", replace(get_parent_terragrunt_dir(), "\\", "/"))
  }
}

remote_state {
  backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config       = local.backend_config
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

inputs = {
  azure_tags = local.unit_common_azure_tags

  # link launchpad network to private DNS zones
  virtual_network_link_id_list = [
    dependency.l0-az-lp-backend.outputs.virtual_networks.l0-launchpad-main.id
  ]
}
