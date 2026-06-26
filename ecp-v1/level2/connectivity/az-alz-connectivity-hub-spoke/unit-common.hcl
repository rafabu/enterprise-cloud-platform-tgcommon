dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L2", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", replace(get_original_terragrunt_dir(), "\\", "/"))
    ] : [],
    [
      # format("%s/../../ecproot/az-platform-subscriptions", replace(get_original_terragrunt_dir(), "\\", "/")),
      # format("%s/../az-alz-shared-library-render", replace(get_original_terragrunt_dir(), "\\", "/"))
    ]
  )))
}

dependency "l0-lp-az-lp-net" {
  config_path = format("%s/../../../level0/launchpad/az-launchpad-network", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    virtual_networks = {
      l0-launchpad-main = {
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
      l0-launchpad-main-default = {
        id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name                 = "mock"
        resource_group_name  = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
  }
  # DANGER ZONE WORKAROUND HERE
  # add "apply" and "destroy" to mock but ONLY UNTIL AFTER https://github.com/gruntwork-io/terragrunt/issues/5993 gets fixed
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l2-con-az-con-mgmt" {
  config_path = format("%s/../az-connectivity-management", replace(get_original_terragrunt_dir(), "\\", "/"))
  mock_outputs = {
    virtual_networks = {
      main_l2-connectivity-management-vnet = {
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
      main-l2-connectivity-management-default = {
        id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name                 = "mock"
        resource_group_name  = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
    key_vault = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock-kv"
      name                = "mock-kv"
      resource_group_name = "mock-rg"
      location            = "westeurope"
    }
  }
  # DANGER ZONE WORKAROUND HERE
  # add "apply" and "destroy" to mock but ONLY UNTIL AFTER https://github.com/gruntwork-io/terragrunt/issues/5993 gets fixed
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_area             = "ecpa"
  ecp_deployment_unit             = "con"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "az-alz-connectivity-hub-spoke"

  library_path_shared = format("%s/lib/ecp-lib", replace(get_repo_root(), "\\", "/"))
  library_path_unit   = "${replace(get_terragrunt_dir(), "\\", "/")}/lib"

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

  # # # ################# virtual WAN #################
  # # # # exclude the ones named in the *.exclude.json
  # # # library_virtualwan_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualWans"
  # # # library_virtualwan_path_unit      = "${local.library_path_unit}/virtualWans"
  # # # library_virtualwan_filter         = "*.virtualWan.json"
  # # # library_virtualwan_exclude_filter = "*.virtualWan.exclude.json"

  # # # # read JSON artefact files and bring them into a map of
  # # # # - artefactName
  # # # #    - filePath
  # # # virtualWan_definition_shared = try({
  # # #   for fileName in fileset(local.library_virtualwan_path_shared, local.library_virtualwan_filter) : jsondecode(file(format("%s/%s", local.library_virtualwan_path_shared, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualwan_path_shared, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_virtualwan_path_shared, fileName)))
  # # #   }
  # # # }, {})
  # # # virtualWan_definition_unit = try({
  # # #   for fileName in fileset(local.library_virtualwan_path_unit, local.library_virtualwan_filter) : jsondecode(file(format("%s/%s", local.library_virtualwan_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualwan_path_unit, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_virtualwan_path_unit, fileName)))
  # # #   }
  # # # }, {})
  # # # virtualWan_definition_exclude_unit = try({
  # # #   for fileName in fileset(local.library_virtualwan_path_unit, local.library_virtualwan_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualwan_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualwan_path_unit, fileName)
  # # #   }
  # # # }, {})
  # # # virtualWan_definition_merged = merge(
  # # #   {
  # # #     for key, val in local.virtualWan_definition_shared : key => val
  # # #     if(contains(keys(local.virtualWan_definition_exclude_unit), key) == false)
  # # #   },
  # # #   local.virtualWan_definition_unit
  # # # )

  # # # ################# virtual WAN hub #################
  # # # # exclude the ones named in the *.exclude.json
  # # # library_virtualhub_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualHubs"
  # # # library_virtualhub_path_unit      = "${local.library_path_unit}/virtualHubs"
  # # # library_virtualhub_filter         = "*.virtualHub.json"
  # # # library_virtualhub_exclude_filter = "*.virtualHub.exclude.json"

  # # # # read JSON artefact files and bring them into a map of
  # # # # - artefactName
  # # # #    - filePath
  # # # virtualHub_definition_shared = try({
  # # #   for fileName in fileset(local.library_virtualhub_path_shared, local.library_virtualhub_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_shared, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualhub_path_shared, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_virtualhub_path_shared, fileName)))
  # # #   }
  # # # }, {})
  # # # virtualHub_definition_unit = try({
  # # #   for fileName in fileset(local.library_virtualhub_path_unit, local.library_virtualhub_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualhub_path_unit, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName)))
  # # #   }
  # # # }, {})
  # # # virtualHub_definition_exclude_unit = try({
  # # #   for fileName in fileset(local.library_virtualhub_path_unit, local.library_virtualhub_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_virtualhub_path_unit, fileName)
  # # #   }
  # # # }, {})
  # # # virtualHub_definition_merged = merge(
  # # #   {
  # # #     for key, val in local.virtualHub_definition_shared : key => val
  # # #     if(contains(keys(local.virtualHub_definition_exclude_unit), key) == false)
  # # #   },
  # # #   local.virtualHub_definition_unit
  # # # )

  # # # ################# virtual vpn Gateway #################
  # # # # exclude the ones named in the *.exclude.json
  # # # library_vpngateway_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/vpnGateways"
  # # # library_vpngateway_path_unit      = "${local.library_path_unit}/vpnGateways"
  # # # library_vpngateway_filter         = "*.vpnGateway.json"
  # # # library_vpngateway_exclude_filter = "*.vpnGateway.exclude.json"

  # # # # read JSON artefact files and bring them into a map of
  # # # # - artefactName
  # # # #    - filePath
  # # # vpnGateway_definition_shared = try({
  # # #   for fileName in fileset(local.library_vpngateway_path_shared, local.library_vpngateway_filter) : jsondecode(file(format("%s/%s", local.library_vpngateway_path_shared, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpngateway_path_shared, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpngateway_path_shared, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnGateway_definition_unit = try({
  # # #   for fileName in fileset(local.library_vpngateway_path_unit, local.library_vpngateway_filter) : jsondecode(file(format("%s/%s", local.library_vpngateway_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpngateway_path_unit, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpngateway_path_unit, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnGateway_definition_exclude_unit = try({
  # # #   for fileName in fileset(local.library_vpngateway_path_unit, local.library_vpngateway_exclude_filter) : jsondecode(file(format("%s/%s", local.library_vpngateway_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpngateway_path_unit, fileName)
  # # #   }
  # # # }, {})
  # # # vpnGateway_definition_merged = merge(
  # # #   {
  # # #     for key, val in local.vpnGateway_definition_shared : key => val
  # # #     if(contains(keys(local.vpnGateway_definition_exclude_unit), key) == false)
  # # #   },
  # # #   local.vpnGateway_definition_unit
  # # # )

  # # # ################# virtual vpn Remote Sites #################
  # # # # exclude the ones named in the *.exclude.json
  # # # library_vpnsite_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/vpnSites"
  # # # library_vpnsite_path_unit      = "${local.library_path_unit}/vpnSites"
  # # # library_vpnsite_filter         = "*.vpnSite.json"
  # # # library_vpnsite_exclude_filter = "*.vpnSite.exclude.json"

  # # # # read JSON artefact files and bring them into a map of
  # # # # - artefactName
  # # # #    - filePath
  # # # vpnSite_definition_shared = try({
  # # #   for fileName in fileset(local.library_vpnsite_path_shared, local.library_vpnsite_filter) : jsondecode(file(format("%s/%s", local.library_vpnsite_path_shared, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnsite_path_shared, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpnsite_path_shared, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnSite_definition_unit = try({
  # # #   for fileName in fileset(local.library_vpnsite_path_unit, local.library_vpnsite_filter) : jsondecode(file(format("%s/%s", local.library_vpnsite_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnsite_path_unit, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpnsite_path_unit, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnSite_definition_exclude_unit = try({
  # # #   for fileName in fileset(local.library_vpnsite_path_unit, local.library_vpnsite_exclude_filter) : jsondecode(file(format("%s/%s", local.library_vpnsite_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnsite_path_unit, fileName)
  # # #   }
  # # # }, {})
  # # # vpnSite_definition_merged = merge(
  # # #   {
  # # #     for key, val in local.vpnSite_definition_shared : key => val
  # # #     if(contains(keys(local.vpnSite_definition_exclude_unit), key) == false)
  # # #   },
  # # #   local.vpnSite_definition_unit
  # # # )

  # # # ################# vpn connections #################
  # # # # exclude the ones named in the *.exclude.json
  # # # library_vpnconnection_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/vpnConnections"
  # # # library_vpnconnection_path_unit      = "${local.library_path_unit}/vpnConnections"
  # # # library_vpnconnection_filter         = "*.vpnConnection.json"
  # # # library_vpnconnection_exclude_filter = "*.vpnConnection.exclude.json"

  # # # # read JSON artefact files and bring them into a map of
  # # # # - artefactName
  # # # #    - filePath
  # # # vpnConnection_definition_shared = try({
  # # #   for fileName in fileset(local.library_vpnconnection_path_shared, local.library_vpnconnection_filter) : jsondecode(file(format("%s/%s", local.library_vpnconnection_path_shared, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnconnection_path_shared, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpnconnection_path_shared, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnConnection_definition_unit = try({
  # # #   for fileName in fileset(local.library_vpnconnection_path_unit, local.library_vpnconnection_filter) : jsondecode(file(format("%s/%s", local.library_vpnconnection_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnconnection_path_unit, fileName)
  # # #     artefact = jsondecode(file(format("%s/%s", local.library_vpnconnection_path_unit, fileName)))
  # # #   }
  # # # }, {})
  # # # vpnConnection_definition_exclude_unit = try({
  # # #   for fileName in fileset(local.library_vpnconnection_path_unit, local.library_vpnconnection_exclude_filter) : jsondecode(file(format("%s/%s", local.library_vpnconnection_path_unit, fileName))).artefactName => {
  # # #     filePath = format("%s/%s", local.library_vpnconnection_path_unit, fileName)
  # # #   }
  # # # }, {})
  # # # vpnConnection_definition_merged = merge(
  # # #   {
  # # #     for key, val in local.vpnConnection_definition_shared : key => val
  # # #     if(contains(keys(local.vpnConnection_definition_exclude_unit), key) == false)
  # # #   },
  # # #   local.vpnConnection_definition_unit
  # # # )


  ################# terragrunt specifics #################
  TG_DOWNLOAD_DIR = replace(coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  ), "\\", "/")

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

    ecp_hub_locations = {}

  # load merged vnet artefact objects
  virtual_network_artefacts = local.virtualNetwork_definition_merged

  # load merged vnet subnet artefact objects
  virtual_network_subnet_artefacts = local.virtualNetworkSubnet_definition_merged

  # which artefacts are active in this unit


  private_dns_zone_ids = dependency.l1-mgm-az-privatelink-privatedns.outputs.private_link_private_dns_zones_resource_ids

  # # # # load merged vpnGateway artefact objects
  # # # vpn_gateway_artefacts = local.vpnGateway_definition_merged

  # # # # load merged expressRoute gateway artefact objects
  # # # # express_route_gateway_artefacts = local.erGateway_definition_merged

  # # # # load merged vpnSite artefact objects
  # # # vpn_site_artefacts = local.vpnSite_definition_merged

  # # # # load merged vpnConnection artefact objects
  # # # vpn_connection_artefacts = local.vpnConnection_definition_merged

  # which artefacts are active in this unit
  ecp_archetype_definitions = {
    name            = "ecpa-hubspoke"
    virtual_network = "l2-connectivity-management-vnet"
    virtual_network_subnet = [
      "l2-connectivity-management-subnet-default"
    ]
    # # # vpn_gateway    = []
    # # # vpn_site       = []
    # # # vpn_connection = []
    # # # er_gateway     = []
    # # # er_connection  = []
  }

  # key vault for PSK secrets
  key_vault_id = dependency.l2-con-az-con-mgmt.outputs.key_vault.id
  
  private_dns_zone_ids = dependency.l1-mgm-az-privatelink-privatedns.outputs.private_link_private_dns_zones_resource_ids
}
