dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L1", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
    ] : [],
    [ 
    format("%s/../az-ecp-parent", get_original_terragrunt_dir())
    ]
  )))
}

locals {
  ecp_deployment_area = "ecpa"
  ecp_deployment_unit             = ""
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-platform-subscriptions"  

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

generate "provider" {
  path      = "providers_alz.tf"
  if_exists = "overwrite"
  contents = <<EOF
provider "alz" {
  # tenant_id       = "local.merged_locals.ecp_entra_tenant_id"
  # subscription_id = "local.ecp_management_subscription_id"
  environment         = "public"
  library_references = [
    {
      path = "platform/alz"
      ref  = "${local.tf_provider_alz_alz_lib_version}"
    },
    # load additional ALZ artifacts via library
    {
      custom_url = "file::${get_repo_root()}/lib/ecp-lib/platform/alz-artefacts/?archive=false"
    },
    # template-rendered local path
    {
      custom_url = "file::c:/temp/ecp-alz-lib/?archive=false"
    }
    # {
    #   path = "platform/slz"
    #   ref  = "${local.tf_provider_alz_slz_lib_version}"
    # },
    # {
    #   path = "platform/amba"
    #   ref  = "${local.tf_provider_alz_amba_lib_version}"
    # }    
  ]
}
EOF
}

inputs = {
    azure_tags = local.unit_common_azure_tags

    launchpad_azure_tags = {
      workloadName = "ecpalp"
      workloadDescription = "ecpa launchpad"
    }
     management_azure_tags = {
      workloadName = "ecpamg"
      workloadDescription = "ecpa management"
    }
     connectivity_azure_tags = {
      workloadName = "ecpanet"
      workloadDescription = "ecpa connectivity"
    }
     identity_azure_tags = {
      workloadName = "ecpaid"
      workloadDescription = "ecpa identity"
    }
    security_azure_tags = {
      workloadName = "ecpasec"
      workloadDescription = "ecpa security"
    }
}
