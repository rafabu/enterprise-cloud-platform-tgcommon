

locals {
  # Read all the locals from the different levels to enable overridable locals e.g. for backend configuration
  root_vars        = read_terragrunt_config(format("%s/../../../../root.hcl", get_terragrunt_dir()))
  env_vars         = read_terragrunt_config(format("%s/../../../env.hcl", get_terragrunt_dir()))
  level_vars       = read_terragrunt_config(format("%s/../../level.hcl", get_terragrunt_dir()))
  area_vars        = read_terragrunt_config(format("%s/../area.hcl", get_terragrunt_dir()))
  unit_common_vars = read_terragrunt_config(format("%s/lib/terragrunt-common/ecp-v1/%s/unit-common.hcl", get_repo_root(), regexall("^.*/(.+?/.+?/.+?)$", get_terragrunt_dir())[0][0]))

  merged_locals = merge(
    local.root_vars.locals,
    local.env_vars.locals,
    local.level_vars.locals,
    local.area_vars.locals,
    local.unit_common_vars.locals
  )

  ######## ECP Defaults ########

  ecp_azure_main_location                        = "WestEurope"
  ecp_network_main_ipv4_address_space            = "10.0.0.0/16"
  ecp_azure_devops_organization_name             = "<not_defined>"
  ecp_azure_devops_project_name                  = "ECP"
  ecp_azure_devops_automation_repository_name    = "ECP.Automation"
  ecp_azure_devops_configuration_repository_name = "ECP.Configuration"
  ecp_azure_root_parent_management_group_id      = "ecp-root"

  deployment_unit_default = "main"

  ######## Merged ECP Data Object ########
  ecp_deployment_data_object = {
    deployment_code                = local.merged_locals.ecp_deployment_code
    deployment_env                 = local.merged_locals.ecp_deployment_env
    deployment_number              = local.merged_locals.ecp_deployment_number
    deployment_area                = local.merged_locals.ecp_deployment_area
    deployment_unit                = try(local.merged_locals.ecp_deployment_unit, local.deployment_unit_default)
    environment_name               = lower("${local.merged_locals.ecp_deployment_code}-${substr(local.merged_locals.ecp_deployment_env, 0, 1)}${local.merged_locals.ecp_deployment_number}")
    launchpad_subscription_id      = local.merged_locals.ecp_launchpad_subscription_id
    management_subscription_id      = local.merged_locals.ecp_management_subscription_id
    # launchpad_resource_group_name  = local.merged_locals.ecp_launchpad_resource_group_name
    # launchpad_storage_account_name = local.merged_locals.ecp_launchpad_storage_account_name
  }

  ######## Launchpad ########
  ecp_launchpad_subscription_id     = coalesce(local.merged_locals.ecp_launchpad_subscription_id, "00000000-0000-0000-0000-000000000000")     # from env.hcl normally
  ecp_management_subscription_id    = local.merged_locals.ecp_management_subscription_id
  ecp_network_subscription_id       = coalesce(local.merged_locals.ecp_network_subscription_id, "00000000-0000-0000-0000-000000000000")
  ecp_identity_subscription_id      = coalesce(local.merged_locals.ecp_identity_subscription_id, "00000000-0000-0000-0000-000000000000")
  ecp_security_subscription_id      = coalesce(local.merged_locals.ecp_security_subscription_id, "00000000-0000-0000-0000-000000000000")
  
  ecp_environment_name = lower("${local.merged_locals.ecp_deployment_code}-${substr(local.merged_locals.ecp_deployment_env, 0, 1)}${local.merged_locals.ecp_deployment_number}")

  ecp_configuration_repo         = "github.com/rafabu/enterprise-cloud-platform-conf.git"
  ecp_configuration_repo_version = "main"

  ecp_azure_modules_repo         = "github.com/rafabu/enterprise-cloud-platform-azure.git"
  ecp_azure_modules_repo_version = "main"

  tfplan_path = get_env("TF_PLAN_PATH", "./")

  ############ Versions ############
  tf_version                      = ">= 1.14"
  tf_provider_azuread_version     = "~> 3.7"
  tf_provider_azurecaf_version    = "~> 1.2"
  tf_provider_azurerm_version     = "~> 4.55"
  tf_provider_azapi_version       = "~> 2.7"
  tf_provider_azuredevops_version = "~> 1.11"
  tf_provider_external_version    = "~> 2.3"
  tf_provider_http_version        = "~> 3.5"
  tf_provider_local_version       = "~> 2.0"
  tf_provider_random_version      = "~> 3.7"
  tf_provider_msgraph_version     = "~> 0.1"
  tf_provider_time_version        = "~> 0.13"
  # ALZ
  tf_provider_alz_version        = "~> 0.20"
  tf_provider_alz_alz_lib_version = "2025.09.3"
  tf_provider_alz_slz_lib_version = "2025.10.1"
  tf_provider_alz_amba_lib_version = "2025.10.1"
  # Azure Verified Modules
  tf_provider_modtm_version        = "~> 0.3"

  ############ Tags ############
  root_common_azure_tags = {
    # "hidden-ecpTgUnitRootCommon" = format("%s/root-common.hcl", get_parent_terragrunt_dir())

    createdBy = "ecp-terraform"
  }

}

# remote state logic is in each unit-common.hcl file
# remote_state {}

terraform {
  source = "git::${local.ecp_azure_modules_repo}/modules-tf//${local.unit_common_vars.locals.azure_tf_module_folder}" # ?ref=${include.root.locals.ecp_azure_modules_repo_version}"

  # Force Terraform to keep trying to acquire a lock for
  # up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()

    arguments = [
      "-lock-timeout=20m"
    ]
  }
  extra_arguments "init" {
    commands = ["init"]
    arguments = [
      "-lock=false" # assure we don't need "Blob Data Contributor"
    ]
  }
  extra_arguments "plan" {
    commands = ["plan"]
    arguments = [
      "--out=${local.tfplan_path}${basename(path_relative_to_include())}.tfplan",
      "-lock=false" # assure we don't need "Blob Data Contributor"
    ]
  }
}

# add providers conditionally based on module name
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents = <<EOF

%{if contains(
  ["az-alz-base"],
  regexall("^.*/(.+?)$", get_terragrunt_dir())[0][0])}
provider "alz" {
  tenant_id       = "${local.merged_locals.ecp_entra_tenant_id}"
  subscription_id = "${local.ecp_management_subscription_id}"
  environment         = "public"
  library_references = [
    {
      path = "platform/alz"
      ref  = "${local.tf_provider_alz_alz_lib_version}"
    },
    # {
    #   path = "platform/slz"
    #   ref  = "${local.tf_provider_alz_slz_lib_version}"
    # },
    # {
    #   path = "platform/amba"
    #   ref  = "${local.tf_provider_alz_amba_lib_version}"
    # },
    # {
    #   custom_url = "${get_repo_root()}/lib"
    # }
  ]
}
%{endif}

%{if contains(
  ["az-alz-base", "ado-mpool", "az-ecp-parent", "az-launchpad-backend", "az-devcenter", "az-launchpad-network", "az-platform-subscriptions"],
  regexall("^.*/(.+?)$", get_terragrunt_dir())[0][0])}
provider "azapi" {
  tenant_id       = "${local.merged_locals.ecp_entra_tenant_id}"
  subscription_id = "${local.ecp_launchpad_subscription_id}"

  environment         = "public"
}
%{endif}

%{if contains(
  ["az-ecp-parent", "ado-mpool", "az-launchpad-bootstrap-helper", "entraid-policies"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
provider "azuread" {
  tenant_id       = "${local.merged_locals.ecp_entra_tenant_id}"
}
%{endif}

provider "azurecaf" {}

%{if contains(
  ["ado-mpool", "ado-project", "ado-repo-sync-automation", "ado-repo-sync-configuration", "ado-pipeline"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
provider "azuredevops" {
  org_service_url = "https://dev.azure.com/$${var.ecp_azure_devops_organization_name}"
}
%{endif}

%{if contains(
  ["ado-mpool", "az-ecp-parent", "az-devcenter", "az-launchpad-bootstrap-finalizer", "az-launchpad-bootstrap-helper", "az-launchpad-main", "az-launchpad-backend", "az-launchpad-network"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
provider "azurerm" {
  alias  = "launchpad"

  tenant_id       = "${local.merged_locals.ecp_entra_tenant_id}"
  subscription_id = "${local.ecp_launchpad_subscription_id}"

  environment         = "public"
  storage_use_azuread = true

  features {}
}
%{endif}

%{if contains(
  ["az-alz-base"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
)[0][0])}
provider "modtm" {
  enabled = false
}
%{endif}

%{if contains(
  ["entraid-policies"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
)[0][0])}
provider "msgraph" {
  tenant_id = "${local.merged_locals.ecp_entra_tenant_id}"
}
%{endif}

EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  required_version = "${local.tf_version}"

  required_providers {
%{if contains(
  ["az-alz-base"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    alz = {
      source  = "azure/alz"
      version = "${local.tf_provider_alz_version}"
    }
%{endif}
%{if contains(
  ["ado-mpool", "az-launchpad-bootstrap-finalizer", "az-launchpad-bootstrap-helper", "entraid-policies"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    azuread = {
      source  = "hashicorp/azuread"
      version = "${local.tf_provider_azuread_version}"
    }
%{endif}
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "${local.tf_provider_azurecaf_version}"
    }
%{if contains(
  ["ado-mpool", "az-devcenter", "az-launchpad-bootstrap-helper", "az-launchpad-backend", "az-launchpad-network", "az-launchpad-main"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "${local.tf_provider_azurerm_version}"
    }
%{endif}
%{if contains(
  ["az-alz-base", "ado-mpool", "az-ecp-parent", "az-launchpad-backend", "az-devcenter", "az-launchpad-network", "az-platform-subscriptions"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    azapi = {
      source  = "azure/azapi"
      version = "${local.tf_provider_azapi_version}"
    }
%{endif}
%{if contains(
  ["ado-mpool", "ado-project", "ado-repo-sync-automation", "ado-repo-sync-configuration", "ado-pipeline"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "${local.tf_provider_azuredevops_version}"
    }
%{endif}
    local = {
      source  = "hashicorp/local"
      version = "${local.tf_provider_local_version}"
    }
    random = {
      source  = "hashicorp/random"
      version = "${local.tf_provider_random_version}"
    }
%{if contains(
  ["entraid-policies"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    msgraph = {
      source  = "Microsoft/msgraph"
      version = "${local.tf_provider_msgraph_version}"
    }
%{endif}
%{if contains(
  ["az-ecp-parent", "az-launchpad-bootstrap-helper"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    external = {
      source  = "hashicorp/external"
      version = "${local.tf_provider_external_version}"
    }
%{endif}
%{if contains(
  ["az-launchpad-bootstrap-helper"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
)[0][0])}
    http = {
      source  = "hashicorp/http"
      version = "${local.tf_provider_http_version}"
    }
%{endif}
%{if contains(
  ["az-alz-base"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
  )[0][0])}
    modtm = {
      source  = "azure/modtm"
      version = "${local.tf_provider_modtm_version}"
    }
%{endif}
%{if contains(
  ["az-alz-base", "az-devcenter","az-ecp-parent", "ado-mpool", "ado-project"],
  regexall("^.*/(.+?)$", get_terragrunt_dir()
)[0][0])}
    time = {
      source  = "hashicorp/time"
      version = "${local.tf_provider_time_version}"
    }
%{endif}
  }
}

EOF
}

inputs = {
  azure_location = local.ecp_azure_main_location
  azure_resource_name_elements = {
    prefixes      = [local.ecp_environment_name]
    name          = local.merged_locals.ecp_deployment_area
    suffixes      = [try(local.merged_locals.ecp_deployment_unit, "main")]
    random_length = try(local.merged_locals.ecp_resource_name_random_length, 0)
  }
  azure_tags = local.root_common_azure_tags

  ecp_environment_name = local.ecp_environment_name

  ecp_network_main_ipv4_address_space            = local.ecp_network_main_ipv4_address_space

  # ECP Platform Azure Subscriptions variables
  ecp_management_subscription_id    = local.ecp_management_subscription_id
  ecp_launchpad_subscription_id     = local.ecp_launchpad_subscription_id
  ecp_identity_subscription_id      = local.ecp_identity_subscription_id
  ecp_security_subscription_id      = local.ecp_security_subscription_id
  ecp_network_subscription_id       = local.ecp_network_subscription_id

  ecp_azure_devops_organization_name             = local.ecp_azure_devops_organization_name
  ecp_azure_devops_project_name                  = local.ecp_azure_devops_project_name
  ecp_azure_devops_automation_repository_name    = local.ecp_azure_devops_automation_repository_name
  ecp_azure_devops_configuration_repository_name = local.ecp_azure_devops_configuration_repository_name
  ecp_azure_root_parent_management_group_id      = local.ecp_azure_root_parent_management_group_id

  ecp_configuration_repo         = local.ecp_configuration_repo
  ecp_configuration_repo_version = local.ecp_configuration_repo_version
  # extract relative path from git repo root to root.hcl file (and remove leading slash if any)
  ecp_configuration_repo_deployment_root_path = replace(replace(replace(dirname(abspath(format("%s/../../../../root.hcl", get_terragrunt_dir()))), "\\", "/"), get_repo_root(), ""), "/^//", "")
}
