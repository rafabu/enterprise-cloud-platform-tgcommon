# dependencies {
#   paths = flatten(distinct(concat(
#     get_env("ECP_TF_BACKEND_STORAGE_AZURE_L2", "") == "" ? [
#       format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
#     ] : [],
#     [
#       # format("%s/../../ecproot/az-platform-subscriptions", get_original_terragrunt_dir()),
#       # format("%s/../az-alz-shared-library-render", get_original_terragrunt_dir())
#     ]
#   )))
# }

# dependency "l1-mgm-az-privatelink-privatedns" {
#   config_path = format("%s/../../../level1/management/az-privatelink-privatedns-zones", get_original_terragrunt_dir())
#   mock_outputs = {
#     private_link_private_dns_zones_resource_ids = [
#       "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.ecpiscool.mock"
#     ]
#     private_link_private_dns_zones = {
#       "ecp_is_cool_mock" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.ecpiscool.mock"
#     }
#   }
#   mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
#   mock_outputs_merge_strategy_with_state  = "shallow"
# }

locals {
  ecp_deployment_area             = "ecpa"
  ecp_deployment_unit             = "con"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-connectivity-management"

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
    for fileName in fileset(local.library_virtualNetworks_path_shared, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualNetworks_path_shared, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName)))
    }
  }, {})
  virtualNetwork_definition_unit = try({
    for fileName in fileset(local.library_virtualNetworks_path_unit, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualNetworks_path_unit, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName)))
    }
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

  ################# virtual network subnet artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworkSubnets_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworkSubnets"
  library_virtualNetworkSubnets_path_unit      = "${local.library_path_unit}/virtualNetworkSubnets"
  library_virtualNetworkSubnets_filter         = "*.virtualNetworkSubnet.json"
  library_virtualNetworkSubnets_exclude_filter = "*.virtualNetworkSubnet.exclude.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  virtualNetworkSubnet_definition_shared = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_shared, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName)))
    }
  }, {})
  virtualNetworkSubnet_definition_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
    }
  }, {})
  virtualNetworkSubnet_definition_exclude_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
  }, {})
  virtualNetworkSubnet_definition_merged = merge(
    {
      for key, val in local.virtualNetworkSubnet_definition_shared : key => val
      if(contains(keys(local.virtualNetworkSubnet_definition_exclude_unit), key) == false)
    },
    local.virtualNetworkSubnet_definition_unit
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
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(
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
  config       = local.backend_config
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

inputs = {
  azure_tags = local.unit_common_azure_tags

  # load merged vnet artefact objects
  virtual_network_artefacts = local.virtualNetwork_definition_merged

  # load merged vnet subnet artefact objects
  virtual_network_subnet_artefacts = local.virtualNetworkSubnet_definition_merged
  
  # which artefacts are active in this unit
  ecp_archetype_definitions = {
    name = "ecpa-con"
    virtual_network = [
      "l2-connectivity-management-vnet"
    ]
    virtual_network_subnet = [
      "l2-connectivity-management-subnet-default"
    ]
  }
}
