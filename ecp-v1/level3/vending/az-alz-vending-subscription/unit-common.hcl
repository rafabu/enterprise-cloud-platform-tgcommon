dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L0", "") == "" || get_env("ECP_TF_BACKEND_STORAGE_AZURE_L1", "") == "" || get_env("ECP_TF_BACKEND_STORAGE_AZURE_L2", "") == "" || get_env("ECP_TF_BACKEND_STORAGE_AZURE_L3", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", replace(get_original_terragrunt_dir(), "\\", "/"))
    ] : [],
    [
      # add additional dependencies here as required
    ]
  )))
}

dependency "l1-con-az-privatelink-privatedns" {
  config_path = format("%s/../../../level1/connectivity/az-privatelink-privatedns-zones", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    private_link_resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
    private_link_private_dns_zones_resource_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.ecpiscool.mock"
    ]
    private_link_private_dns_zones = {
      "ecp_is_cool_mock" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.ecpiscool.mock"
    }
  }
  # DANGER ZONE WORKAROUND HERE
  # add "apply" and "destroy" to mock but ONLY UNTIL AFTER https://github.com/gruntwork-io/terragrunt/issues/5993 gets fixed
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l2-con-az-con-bastion" {
  config_path = format("%s/../../../level2/connectivity/az-connectivity-bastion", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    virtual_networks = {
      main = {
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
      main = {
        id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name                 = "mock"
        resource_group_name  = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
    bastion_hosts = {
      main = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/bastionHosts/mock-bastion"
        name                = "mock-bastion"
        resource_group_name = "mock-rg"
        location            = "westeurope"
      }
    }
    bastion_host_reader_permission_group_object_id = "00000000-0000-0000-0000-000000000000"
  }
  # DANGER ZONE WORKAROUND HERE
  # add "apply" and "destroy" to mock but ONLY UNTIL AFTER https://github.com/gruntwork-io/terragrunt/issues/5993 gets fixed
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l2-con-az-con-vwan" {
  config_path = format("%s/../../../level2/connectivity/az-alz-connectivity-virtual-wan", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    azure_virtual_wan_name = "mock-vwan"
    azure_virtual_wan_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualWans/mock-vwan"
    azure_virtual_wan_hub_resource_ids = {
      main = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualHubs/mock-vhub"
    }
    azure_virtual_wan_hub_resource_names = {
      main = "mock-vhub"
    }
    azure_virtual_wan_hub_resource_details = {
      main = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualHubs/mock-vhub"
        name                = "mock-vhub"
        location            = "westeurope"
        address_prefix = "192.0.2.0/24"
      }
    }
  }
  # DANGER ZONE WORKAROUND HERE
  # add "apply" and "destroy" to mock but ONLY UNTIL AFTER https://github.com/gruntwork-io/terragrunt/issues/5993 gets fixed
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  #ecp_deployment_area             = "" # vending uses its own naming convention
  # ecp_deployment_unit             = "" # vending uses its own naming convention
  # ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-alz-vending-subscription"

  library_path_shared = format("%s/lib/ecp-lib", replace(get_repo_root(), "\\", "/"))
  library_path_unit   = "${replace(get_terragrunt_dir(), "\\", "/")}/lib"

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
  TG_DOWNLOAD_DIR = replace(coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  ), "\\", "/")

  # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_LEVEL3_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL3_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL3_NAME", "") != "",
    get_env("ECP_TG_BACKEND_LEVEL3_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(
    try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )

  bootstrap_backend_type         = "azurerm"
  bootstrap_backend_type_changed = false

  backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_LEVEL3_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_LEVEL3_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_LEVEL3_NAME")
    container_name       = get_env("ECP_TG_BACKEND_LEVEL3_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l3"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l3"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l3"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l3"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  }

  ################# tags #################
  unit_common_azure_tags = {
    # "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", replace(get_parent_terragrunt_dir(), "\\", "/"))
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



  # ecp_hub_locations = {}

  # # load merged vnet artefact objects
  # virtual_network_artefacts = local.virtualNetwork_definition_merged

  # # load merged vnet subnet artefact objects
  # virtual_network_subnet_artefacts = local.virtualNetworkSubnet_definition_merged

  # which artefacts are active in this unit
  # ecp_archetype_definitions = {
  #   name            = "ecpa-con"
  #   virtual_network = "l2-connectivity-management-vnet"
  #   virtual_network_subnet = [
  #     "l2-connectivity-management-subnet-default"
  #   ]
  # }

  vwan_hub_resources_by_location = dependency.l2-con-az-con-vwan.outputs.azure_virtual_wan_hub_resource_details_by_location
  vwan_resource_id = dependency.l2-con-az-con-vwan.outputs.azure_virtual_wan_resource_id

  bastion_vnet_id = dependency.l2-con-az-con-bastion.outputs.virtual_networks["main"].id
  bastion_resource_id = dependency.l2-con-az-con-bastion.outputs.bastion_hosts["main"].id

  private_dns_zone_resource_group_id = dependency.l1-con-az-privatelink-privatedns.outputs.private_link_resource_group_id

  additional_entra_id_group_members = {
    bastion = {
      group_object_id = dependency.l2-con-az-con-bastion.outputs.bastion_host_reader_permission_group_object_id
      role_group_keys = [
        "lz-owner",
        "lz-user"
      ]
    }
  }
}
