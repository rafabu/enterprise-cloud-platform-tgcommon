dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
  #  mock_outputs = {
  #   resource_group = {
  #     id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
  #     name = "mock-rg"
  #     location = "nowhere"
  #   }
  #   storage_accounts = {
  #     l0 = {
  #       id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl0"
  #       name = "mockstl0"
  #       location = "nowhere"
  #       private_endpoint_blob ={
  #         fqdn = "mockstl0.blob.core.windows.net"
  #         private_ip_address = "192.0.2.4"
  #       }
  #       ecp_level = "l0"
  #       tf_backend_container = "tfstate"
  #     }
  #     l1 = {
  #       id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl1"
  #       name = "mockstl1"
  #       location = "nowhere"
  #       private_endpoint_blob ={
  #         fqdn = "mockstl1.blob.core.windows.net"
  #         private_ip_address = "192.0.2.5"
  #       }
  #       ecp_level = "l1"
  #       tf_backend_container = "tfstate"
  #     }
  #     l2 = {
  #       id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl2"
  #       name = "mockstl2"
  #       location = "nowhere"
  #       private_endpoint_blob ={
  #         fqdn = "mockstl2.blob.core.windows.net"
  #         private_ip_address = "192.0.2.6"
  #       }
  #       ecp_level = "l2"
  #       tf_backend_container = "tfstate"
  #     }
  #   }
  # }
}

locals {
  ecp_deployment_unit = "main"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-main"

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }

  zzz_file = format("%s/../az-launchpad-bootstrap-helper/lp-bootstrap-backend-details.json", get_working_dir())
  # zzz_flag = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists

}

# work with local backend if remote backend doesn't exist yet
# remote_state {
# %{if file("${path.module}/../az-launchpad-backend/lp-bootstrap-backend-details.json")(
#   ["az-launchpad-bootstrap-helper"],
#   regexall("^.*/(.+?)$", get_terragrunt_dir()
# )[0][0])}
#     external = {
#       source  = "hashicorp/external"
#       version = "${local.tf_provider_external_version}"
#     }
# %{endif}


#   backend =   "azurerm"
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite"
#   }
#   config = {
#     subscription_id      = local.ecp_launchpad_subscription_id
#     resource_group_name  = local.ecp_launchpad_resource_group_name
#     storage_account_name = local.ecp_launchpad_storage_account_name
#     container_name       = "tfstate"
#     use_azuread_auth     = true
#     key                  = "${basename(path_relative_to_include())}.tfstate"
#   }
#   disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
# }

# dependency.l0-lp-az-backend.outputs.storage_accounts


inputs = {
  azure_tags = local.unit_common_azure_tags


   zzz_file = local.zzz_file
   zzz_working_dir = get_working_dir()
}
