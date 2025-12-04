dependencies {
  paths = [
    format("%s/../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
  ]
}

locals {
  ecp_deployment_unit             = "az-management"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-ecp-parent"  

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type         = "azurerm"
  bootstrap_backend_type_changed = false
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"
}

remote_state {
  backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.bootstrap_backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l1"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l1"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l1"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l1"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    path = local.bootstrap_local_backend_path
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

inputs = {}
