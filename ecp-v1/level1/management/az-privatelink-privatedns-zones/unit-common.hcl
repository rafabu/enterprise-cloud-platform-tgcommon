dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L1", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
    ] : [],
    [ 
    format("%s/../../ecproot/az-platform-subscriptions", get_original_terragrunt_dir())
    ]
  )))
}

dependency "l0-lp-az-lp-net" {
  config_path = format("%s/../../../level0/launchpad/az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
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
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}


dependency "az-ecp-parent" {
  config_path = format("%s/../../ecproot/az-ecp-parent", get_original_terragrunt_dir())
   mock_outputs = {
    parent_management_group_name = "mock-mg"
    parent_management_group_id = "/providers/Microsoft.Management/managementGroups/mock-mg"
    role_group_contributor_name = "mock-role-group-contributor"
    role_group_contributor_id = "00000000-0000-0000-0000-000000000000"
    role_group_reader_name = "mock-role-group-reader"
    role_group_reader_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_area = "ecpa"
  ecp_deployment_unit = "conn"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-privatelink-privatedns-zones"

# alz library paths (learn what private DNS zones exist in ALZ's own policy initiative artefacts)
#     - Deploy-Private-DNS-Zones
    # alz_library_path_shared = format("%s/lib/ecp-lib/platform/alz-artefacts/", get_repo_root())
    # alz_library_path_unit   = "${get_terragrunt_dir()}/lib/"
    # # folder where rendered template alz library files are places (temporarily)
    # alz_library_path_shared_rendered  = "${trimsuffix(local.TG_DOWNLOAD_DIR, "/")}/${uuidv5("dns", "${local.alz_library_path_shared}")}/"

  ################# terragrunt specifics #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )

 # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_LEVEL1_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL1_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(
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
  }

    ################# tags #################
  unit_common_azure_tags = {
    # "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
} 

remote_state {
  backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.backend_config
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

inputs = {
    azure_tags = local.unit_common_azure_tags

    # link launchpad network to private DNS zones
    virtual_network_link_id_list = [
      dependency.l0-lp-az-lp-net.outputs.virtual_network_subnets.l0-launchpad-main-default.id
    ]
}
