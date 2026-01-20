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
    # for fileName in fileset(local.library_virtualNetworks_path_shared, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName)))
    for fileName in fileset(local.library_virtualNetworks_path_shared, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualNetworks_path_shared, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_shared, fileName)))
    }
  }, {})
  virtualNetwork_definition_unit = try({
    # for fileName in fileset(local.library_virtualNetworks_path_unit, local.library_virtualNetworks_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworks_path_unit, fileName)))
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

################# virtual WAN hub #################
  # exclude the ones named in the *.exclude.json
  library_virtualhub_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualHubs"
  library_virtualhub_path_unit      = "${local.library_path_unit}/virtualHubs"
  library_virtualhub_filter         = "*.virtualHub.json"
  library_virtualhub_exclude_filter = "*.virtualHub.exclude.json"

  # read JSON artefact files and bring them into a map of
  # - artefactName
  #    - filePath
  virtualHub_definition_shared = try({
    for fileName in fileset(local.library_virtualhub_path_shared, local.library_virtualhub_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_shared, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualhub_path_shared, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualhub_path_shared, fileName)))
    }
  }, {})
  virtualHub_definition_unit = try({
    for fileName in fileset(local.library_virtualhub_path_unit, local.library_virtualhub_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualhub_path_unit, fileName)
      artefact = jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName)))
    }
  }, {})
  virtualHub_definition_exclude_unit = try({
    for fileName in fileset(local.library_virtualhub_path_unit, local.library_virtualhub_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualhub_path_unit, fileName))).artefactName => {
      filePath = format("%s/%s", local.library_virtualhub_path_unit, fileName)
    }
  }, {})
  virtualHub_definition_merged = merge(
    {
      for key, val in local.virtualHub_definition_shared : key => val
      if(contains(keys(local.virtualHub_definition_exclude_unit), key) == false)
    },
    local.virtualHub_definition_unit
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
  # virtual_network_definitions = local.virtualNetwork_definition_merged

  # load merged virtual hub artefact objects
  virtual_hub_artefacts = local.virtualHub_definition_merged


  virtual_wan_hubs = {
    "ecpa-default-location" = {

      # enabled_resources = {
      #   firewall                              = null
      #   firewall_policy                       = null
      #   bastion                               = null
      #   virtual_network_gateway_express_route = null
      #   virtual_network_gateway_vpn           = true
      #   private_dns_zones                     = null
      #   private_dns_resolver                  = null
      #   sidecar_virtual_network               = null
      # }

      # if not given; default ecpa location (var.azure_location) is chosen
      location = null
      # virtualNetwork artefactName (defines address space))
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
        subnet_address_prefix                     = null
        subnet_default_outbound_access_enabled    = null
        route_table_creation_enabled              = null
        route_table_name                          = null
        route_table_bgp_route_propagation_enabled = null
        express_route = {
          allow_non_virtual_wan_traffic = null
          scale_units                   = null
        }
        vpn = {
          name         = null
          bgp_settings = null
          scale_unit   = null
        }
      }

      vpn_sites = {
        "ecp-onprem-mock" = {
          # display name - 80 char; no spaces
          name = "ECP-OnPrem-Mock"
          links = [
            {
              name = "link1"
              bgp  = null
              # bgp = {
              #   asn             = 3321
              #   peering_address = "192.168.0.1"
              # }
              fqdn          = null
              ip_address    = "192.0.2.2"
              provider_name = null
              speed_in_mbps = null
            }
          ]
          address_cidrs = [
            "192.0.2.0/24"
          ]
          device_model  = null
          device_vendor = null
          o365_policy   = null
        }
      }

      vpn_site_connections = {
        "ecp-onprem-mock-connection" = {
          # must match key of vpn_sites
          vpn_site_key = "ecp-onprem-mock"

          vpn_links = [
            {
              vpn_site_link_number = 0
              connection_mode      = null

              ipsec_policy = {
                #                                         Portal Names
                # IKE Mode (Phase 1)                    --------------------------
                dh_group                 = "DHGroup14" # Phase 1: DH Group
                ike_encryption_algorithm = "AES256"    # Phase 1: Encryption
                ike_integrity_algorithm  = "SHA384"    # Phase 1: Integrity/PRF

                # IPSec Mode (Phase 2)
                pfs_group            = "PFS14"     # Phase 2: PFS Group
                encryption_algorithm = "GCMAES256" # Phase 2: IPsec Encryption
                integrity_algorithm  = "GCMAES256" # Phase 2: IPsec Integrity
                sa_data_size_kb      = 0
                sa_lifetime_sec      = 27000
              }

              protocol   = "IKEv2"
              shared_key = null # "ExAmPlE_SeCrEt_KeY_NoT_ReAl_12345!@#$%"
            }
          ]
        }
      }
    }
  }
}
