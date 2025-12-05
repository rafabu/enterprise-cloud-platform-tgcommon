dependencies {
  paths = [
    format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir()),
    format("%s/../../../level0/finalizer/az-launchpad-bootstrap-finalizer", get_original_terragrunt_dir())
  ]
}

dependency "l0-lp-ado-mpool" {
  config_path = format("%s/../../../level0/launchpad/ado-mpool", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    managed_devops_pool = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevOps/managedDevOpsPools/mock-pool"
      id_azuredevops = "0"
      name = "mock-pool"
      resource_group_name = "mock-rg"
      location = "westeurope"
    }
     service_principals = {
      "l0-contribute" = {
        id   = "00000000-0000-0000-0000-000000000000"
        display_name = "mock_name"
        client_id = "00000000-0000-0000-0000-000000000000"
        object_id = "00000000-0000-0000-0000-000000000000"
        type = "managedIdentity"
      }
      "l0-read" = {
        id   = "00000000-0000-0000-0000-000000000000"
        display_name = "mock_name"
        client_id = "00000000-0000-0000-0000-000000000000"
        object_id = "00000000-0000-0000-0000-000000000000"
        type = "managedIdentity"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_unit             = "ecproot"
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

inputs = {
  ecp_deployment_entraid_contributor_group_member_principal_ids = [
    "111d8248-5407-4cc2-8482-67f182b8cd78" # Adele Vance / AdeleV@m365.rabuzu.com
  ]
  ecp_deployment_entraid_contributor_groups_protected = true
  ecp_deployment_entraid_contributor_group_pim_enabled = true

  ecp_deployment_entraid_reader_group_member_principal_ids      = [
    "111d8248-5407-4cc2-8482-67f182b8cd78", # Adele Vance / AdeleV@m365.rabuzu.com
    "5c929fb8-b2eb-46de-99e3-c7a63127358a" # Alex Wilber / AlexW@m365.rabuzu.com
  ]
  ecp_deployment_entraid_reader_groups_protected = false
  ecp_deployment_entraid_reader_group_pim_enabled = false

  ecp_deployment_contributor_workload_identity_object_id = dependency.l0-lp-ado-mpool.outputs.service_principals["l0-contribute"].object_id
  ecp_deployment_reader_workload_identity_object_id  = dependency.l0-lp-ado-mpool.outputs.service_principals["l0-read"].object_id
}
