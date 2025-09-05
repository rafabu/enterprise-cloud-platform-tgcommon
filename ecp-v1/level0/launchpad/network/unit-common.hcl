dependency "0-lp-net" {
  config_path = format("%s/../network", get_original_terragrunt_dir())
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example"
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Network/virtualNetworks/vnet-example"
  }
}

locals {
  ecp_deployment_unit = "ado-mpool"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-mpool"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"

  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

inputs = {
}
