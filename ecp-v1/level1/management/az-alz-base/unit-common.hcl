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
  ecp_deployment_unit = "management"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-alz-base"  

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

    alz_parent_management_group_resource_id = dependencies.az-ecp-parent.outputs.parent_management_group_id
}
