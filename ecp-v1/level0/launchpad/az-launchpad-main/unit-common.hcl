dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
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
}

locals {
  ecp_deployment_unit = "main"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-main"

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
}
