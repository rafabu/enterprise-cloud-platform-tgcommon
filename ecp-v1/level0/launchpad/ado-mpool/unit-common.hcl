dependency "l0-lp-az-net" {
  config_path = format("%s/../az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
    virtual_networks = {
      l0-launchpad-main = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
        name = "mock-vnet"
        resource_group_name = "mock-rg"
        location = "nowhere"
        address_space = [
          "192.0.2.0/24"
        ]
      }
    }
    virtual_network_subnets = {
      l0-launchpad-main-default = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name = "mock"
        resource_group_name = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "l0-lp-az-backend" {
  config_path = format("%s/../az-launchpad-backend", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
    storage_accounts = {
      l0 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl0"
        name = "mockstl0"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl0.blob.core.windows.net"
          private_ip_address = "192.0.2.4"
        }
        ecp_level = "l0"
        tf_backend_container = "tfstate"
      }
      l1 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl1"
        name = "mockstl1"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl1.blob.core.windows.net"
          private_ip_address = "192.0.2.5"
        }
        ecp_level = "l1"
        tf_backend_container = "tfstate"
      }
      l2 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl2"
        name = "mockstl2"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl2.blob.core.windows.net"
          private_ip_address = "192.0.2.6"
        }
        ecp_level = "l2"
        tf_backend_container = "tfstate"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "l0-lp-az-devcenter" {
  config_path = format("%s/../az-devcenter", get_original_terragrunt_dir())
  mock_outputs = {
    dev_center = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/devcenters/mock-devcenter"
      name = "mock-devcenter"
      location = "nowhere"
      resource_group_name = "mock-rg"
    }
    dev_center_project = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/projects/mock-project"
        name = "mock-project "
        location = "nowhere"
        resource_group_name = "mock-rg"
      }
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "l0-lp-az-ado-project" {
  config_path = format("%s/../ado-project", get_original_terragrunt_dir())
  mock_outputs = {}
}

locals {
  ecp_deployment_unit = "ado-mpool"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-mpool"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"

  ################# virtual network subnet artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworkSubnets_path_shared = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworkSubnets"
  library_virtualNetworkSubnets_path_unit= "${local.library_path_unit}/virtualNetworkSubnets"
  library_virtualNetworkSubnets_filter = "*.virtualNetworkSubnet.json"
  library_virtualNetworkSubnets_exclude_filter = "*.virtualNetworkSubnet.exclude.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  virtualNetworkSubnet_definition_shared = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_shared, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName)))
  }, {})
  virtualNetworkSubnet_definition_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
  }, {})
  virtualNetworkSubnet_definition_exclude_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
  }, {})
  virtualNetworkSubnet_definition_merged = merge(
    {
      for key, val in local.virtualNetworkSubnet_definition_shared : key => val
      if (contains(keys(local.virtualNetworkSubnet_definition_exclude_unit), key) == false)
    },
    local.virtualNetworkSubnet_definition_unit
  )

################# tags #################
  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
   
  virtual_network_id = dependency.l0-lp-az-net.outputs.virtual_networks.l0-launchpad-main.id
  
  # load merged vnet artefact objects
  virtual_network_subnet_definitions = local.virtualNetworkSubnet_definition_merged

  # define which artefacts from the libraries we need to create
  subnet_artefact_names = [
    "l0-launchpad-ado-mpool-platform"
  ]

  backend_storage_accounts = dependency.l0-lp-az-backend.outputs.storage_accounts

  workload_identity_type = "userAssignedIdentity" # "serviceprincipal"

  dev_center_project_resource_id = dependency.l0-lp-az-devcenter.outputs.dev_center_project.id
}
