dependencies {
  paths = flatten(distinct(concat(
    get_env("ECP_TF_BACKEND_STORAGE_AZURE_L2", "") == "" ? [
      format("%s/../../../level0/bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
    ] : [],
    [
      # format("%s/../../ecproot/az-platform-subscriptions", get_original_terragrunt_dir()),
      # format("%s/../az-alz-shared-library-render", get_original_terragrunt_dir())
    ]
  )))
}

dependency "l0-lp-az-lp-net" {
  config_path = format("%s/../../../level0/launchpad/az-launchpad-network", get_original_terragrunt_dir())
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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_area             = "ecpa"
  ecp_deployment_unit             = "conn"
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
  virtual_network_definitions = local.virtualNetwork_definition_merged

  virtual_wan_hubs = {
    "ecpa-default-location" = {

      enabled_resources = {
        firewall                              = null
        firewall_policy                       = null
        bastion                               = null
        virtual_network_gateway_express_route = null
        virtual_network_gateway_vpn           = true
        private_dns_zones                     = null
        private_dns_resolver                  = null
        sidecar_virtual_network               = null
      }

      # if not given; default ecpa location is chosen
      location = null
      # vnet artefact (defines address space))
      address_prefix_artefact_name = "l2-connectivity-vwan-hub"
      
      # SKU defined in root-common such that it can be overridden on the entire unit config tree of deployments
      # sku = "Basic"

      virtual_network_connections = {
        ecpa-launchpad = {
          remote_virtual_network_id = dependency.l0-lp-az-lp-net.outputs.virtual_networks.l0-launchpad-main.id
          # internet_security_enabled (route via Azure firewall) has been superseded by routing_intent
          internet_security_enabled = false
        }
      }

      virtual_network_gateways = {
        subnet_address_prefix = null
        subnet_default_outbound_access_enabled = null
        route_table_creation_enabled = null
        route_table_name = null
        route_table_bgp_route_propagation_enabled = null
          express_route = {
            allow_non_virtual_wan_traffic = null
            scale_units = null
          }
          vpn = {
            name = null
            bgp_settings = null
            scale_unit = null
        }
      }
    }
  }
}
