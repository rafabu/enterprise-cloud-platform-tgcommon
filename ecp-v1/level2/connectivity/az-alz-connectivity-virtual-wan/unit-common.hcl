dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L1", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
    ] : [],
    [ 
    format("%s/../../ecproot/az-platform-subscriptions", get_original_terragrunt_dir()),
    format("%s/../az-alz-shared-library-render", get_original_terragrunt_dir())
    ]
  )))
}

locals {
  ecp_deployment_area = "ecpa"
  ecp_deployment_unit = "conn"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-alz-connectivity-virtual-wan"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit   = "${get_terragrunt_dir()}/lib"

  ################# virtual network artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworks_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworks"
  library_virtualNetworks_path_unit      = "${local.library_path_unit}/virtualNetworks"
  library_virtualNetworks_filter         = "*.virtualNetwork.json"
  library_virtualNetworks_exclude_filter = "*.virtualNetwork.exclude.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  virtualNetwork_definition_shared = try({
    for fileName in fileset(local.library_virtualNetworks_path_shared, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName)))
  }, {})
  virtualNetwork_definition_unit = try({
    for fileName in fileset(local.library_virtualNetworks_path_unit, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName)))
  }, {})
  virtualNetwork_definition_exclude_unit = try({
    for fileName in fileset(local.library_virtualNetworks_path_unit, local.library_virtualNetworks_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName)))
  }, {})
  virtualNetwork_definition_merged = merge(
    {
      for key, val in local.virtualNetwork_definition_shared : key => val
      if(contains(keys(local.virtualNetwork_definition_exclude_unit), key) == false)
    },
    local.virtualNetwork_definition_unit
  )


  ################# terragrunt specifics #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )

 # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_LEVEL2_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL2_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL2_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL2_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(
      try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )

  bootstrap_backend_type         = "azurerm"
  bootstrap_backend_type_changed = false

   backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_LEVEL2_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_LEVEL2_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_LEVEL2_NAME")
    container_name       = get_env("ECP_TG_BACKEND_LEVEL2_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l2"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l2"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l2"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l2"].tf_backend_container
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

  # load merged vnet artefact objects
  virtual_network_definitions        = local.virtualNetwork_definition_merged
  
  virtual_wan_hubs = {
    "default-basic" = {
      address_prefix_artefact_name    = "l2-connectivity-vwan-hub" 
      sku = "Basic"
    }
  }
}
