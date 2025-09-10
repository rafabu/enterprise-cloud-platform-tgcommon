locals {
  ecp_deployment_unit = "ado-organization"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-organization"

  ################# tags #################
  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
}
