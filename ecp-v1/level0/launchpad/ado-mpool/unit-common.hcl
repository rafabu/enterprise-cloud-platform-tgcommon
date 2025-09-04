locals {
  ecp_deployment_unit = "ado-mpool"

  azure_tf_module_folder = "ado-mpool"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"

  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

inputs = {
}
