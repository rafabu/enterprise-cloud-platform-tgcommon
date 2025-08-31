locals {
  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"


  ################# named location artefacts #################
  library_namedLocation_path_shared = "${local.library_path_shared}/platform/ecp-artefacts/ms-entra/entraid-policies/namedLocations"
  library_namedLocation_path_unit= "${local.library_path_unit}/namedLocations"
  library_namedLocation_filter = "*.microsoft.graph.{country,ip}NamedLocation.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  policy_named_location_definition_shared = try({
    for fileName in fileset(local.library_namedLocation_path_shared, local.library_namedLocation_filter) : jsondecode(file(format("%s/%s", local.library_namedLocation_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_namedLocation_path_shared, fileName)))
  }, {})
  policy_named_location_definition_unit = try({
    for fileName in fileset(local.library_namedLocation_path_unit, local.library_namedLocation_filter) : jsondecode(file(format("%s/%s", local.library_namedLocation_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_namedLocation_path_unit, fileName)))
  }, {})
  policy_named_location_definition_merged = merge(
    local.policy_named_location_definition_shared,
    local.policy_named_location_definition_unit
  )

   ################ conditional access policy artefacts #################
  library_capol_path_shared = "${local.library_path_shared}/platform/ecp-artefacts/ms-entra/entraid-policies/conditionalAccessPolicy"
  library_capol_path_unit = "${local.library_path_unit}/conditionalAccessPolicy"
  library_capol_filter = "*.microsoft.graph.conditionalAccessPolicy.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  policy_ca_definition_shared = try({
    for fileName in fileset(local.library_capol_path_shared, local.library_capol_filter) : jsondecode(file(format("%s/%s", local.library_capol_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_capol_path_shared, fileName)))
  }, {})
  policy_ca_definition_unit = try({
    for fileName in fileset(local.library_capol_path_unit, local.library_capol_filter) : jsondecode(file(format("%s/%s", local.library_capol_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_capol_path_unit, fileName)))
  }, {})
  policy_ca_definition_merged = merge(
    local.policy_ca_definition_shared,
    local.policy_ca_definition_unit
  )
}

inputs = {
  # named location and CA policy artefacts (merged - unit definitions can override the library ones)
  named_location_definitions =   local.policy_named_location_definition_merged
  conditional_access_policy_definitions =   local.policy_ca_definition_merged
 
}
