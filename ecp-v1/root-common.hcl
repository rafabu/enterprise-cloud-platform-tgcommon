

locals {
  # Read all the locals from the different levels to enable overridable locals e.g. for backend configuration
    root_vars = read_terragrunt_config(format("%s/../../../../root.hcl", get_original_terragrunt_dir()))
    env_vars = read_terragrunt_config(format("%s/../../../env.hcl", get_original_terragrunt_dir()))
    level_vars = read_terragrunt_config(format("%s/../../level.hcl", get_original_terragrunt_dir()))
    area_vars = read_terragrunt_config(format("%s/../area.hcl", get_original_terragrunt_dir()))
    unit_common_vars = read_terragrunt_config(format("%s/lib/terragrunt-common/ecp-v1/%s/unit-common.hcl", get_repo_root(), regexall("^.*/(.+?/.+?/.+?)$", get_original_terragrunt_dir())[0][0]))
    merged_locals = merge(
      local.root_vars.locals,
      local.env_vars.locals,
      local.level_vars.locals,
      local.area_vars.locals,
      local.unit_common_vars.locals
    )

  launchpad_subscription_id      = local.merged_locals.launchpad_subscription_id # from env.hcl normally
  launchpad_resource_group_name  = local.merged_locals.launchpad_resource_group_name # from level.hcl normally
  launchpad_storage_account_name = local.merged_locals.launchpad_storage_account_name # from level.hcl normally

  environment_name = lower("${local.merged_locals.deployment_code}-${substr(local.merged_locals.deployment_env, 0, 1)}${local.merged_locals.deployment_number}")

  azure_modules_repo = "github.com/rafabu/enterprise-cloud-platform-azure.git"
  azure_modules_repo_version      = "main"

  tfplan_path                    = get_env("TF_PLAN_PATH", "./")

  merged_azure_tags = merge(
    local.root_common_azure_tags,
    local.root_vars.locals.root_azure_tags,
    local.env_vars.locals.env_azure_tags,
    local.level_vars.locals.level_azure_tags,
    local.area_vars.locals.area_azure_tags,
    local.unit_common_vars.locals.unit_common_azure_tags
  )

  root_common_azure_tags = {
    "_ecpTgUnitRootCommon" = format("%s/root-common.hcl", get_parent_terragrunt_dir())
  }

}

remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    subscription_id      = local.launchpad_subscription_id
    resource_group_name  = local.launchpad_resource_group_name
    storage_account_name = local.launchpad_storage_account_name
    container_name       = "tfstate"
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {
   source = "git::${local.azure_modules_repo}/modules-tf//entraid-policies" # ?ref=${include.root.locals.azure_modules_repo_version}"

  # Force Terraform to keep trying to acquire a lock for
  # up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()

    arguments = [
      "-lock-timeout=20m"
    ]
  }
  extra_arguments "plan" {
    commands = ["plan"]
    arguments = [
      "--out=${local.tfplan_path}${basename(path_relative_to_include())}.tfplan"
    ]
  }
}

inputs = {
}
