# dependency "l0-lp-az-lp-bootstrap-helper" {
#   config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
# }

dependencies {
  paths = [ format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())]
}

locals {
  ecp_deployment_unit = "main"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-main"

################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = get_env("TG_DOWNLOAD_DIR", trimspace(run_cmd("pwsh", "-NoLogo", "-NoProfile", "-Command", "[System.IO.Path]::GetTempPath()")))
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type = local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true  && get_terraform_command() != "destroy" ? "azurerm" : "local"
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
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

  before_hook "Migrate-TerraformState" {
    commands     = [
      "apply",
      "destroy",  # during destroy the remote state should no longer be present
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

Write-Output "INFO: check if backend migration to backend '${local.bootstrap_backend_type}' is required"
terraform init -backend=false -input=false | Out-Null
$check = terraform init -reconfigure -input=false -migrate-state=false 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "     backend migration required; performing migration now..."
    terraform init -migrate-state -input=false -force-copy
}
else {
    Write-Output "    backend configuration matches; no migration required."
}
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
}
