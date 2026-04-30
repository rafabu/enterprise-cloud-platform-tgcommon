#
# Helper config which extracts runtime information via terraform data sources and
#     drops them into local JSON files for consumption by scripts and other tools
#     downstream
#

locals {
  ecp_deployment_unit             = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-bootstrap-helper"

  library_path_shared = format("%s/lib/ecp-lib", replace(get_repo_root(), "\\", "/"))
  library_path_unit   = "${replace(get_terragrunt_dir(), "\\", "/")}/lib"

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

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", basename(replace(get_original_terragrunt_dir(), "\\", "/")))}"
  bootstrap_helper_output        = try(jsondecode(file(local.bootstrap_helper_output_file)), {})
  bootstrap_backend_type         = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true && get_terraform_command() != "destroy" ? "azurerm" : "local", "local")
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  bootstrap_local_backend_path   = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"
  # check if remote backend already existed when helper ran last time (consume its own output file)
  bootstrap_helper_output_file = "${local.bootstrap_helper_folder}/terraform_output.json"
}

# helper module does not need a backend; can and should run with local state (as it is kind of stateless anyway)
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = local.bootstrap_local_backend_path
  }
}

terraform {

  before_hook "create-terraform-output-folder" {
    commands = [
      "apply",
      "plan"
    ]
    execute = [
      "pwsh",
      "-File",
      "${replace(get_parent_terragrunt_dir(), "\\", "/")}/scripts/Create-Terraform-Output-Folder.ps1",
      "-unitName", "${uuidv5("dns", basename(replace(get_original_terragrunt_dir(), "\\", "/")))}"
    ]
    run_on_error = false
  }

  after_hook "write-terraform-output-to-file" {
    commands = [
      "apply",
      "plan"
    ]
    execute = [
      "pwsh",
      "-File",
      "${replace(get_parent_terragrunt_dir(), "\\", "/")}/scripts/Write-Terraform-Output-to-File.ps1",
      "-unitName", "${uuidv5("dns", basename(replace(get_original_terragrunt_dir(), "\\", "/")))}"
    ]
    run_on_error = false
  }

  # enable remote backend access if conditions are met:
  #    - storage account exists
  #    - actor IP is outside of launchpad vnet range
  #    - actor identity is not the ECP Identity (which should have access anyway)
  #    - storage account is not accessible with the current private IP (e.g. after PIP IP had changed, routing is missing or similar)
  after_hook "Enable-PostHelper-RemoteBackend-Access" {
    commands = [
      "apply",
      # "destroy",  # during destroy the remote state should no longer be present
      # "force-unlock",
      "import",
      # "init", # on initial run, no outputs will be available, yet
      "output",
      "plan",
      "refresh",
      # "state",
      # "taint",
      # "untaint",
      # "validate"
    ]

    execute = [
      "pwsh",
      "-NoLogo", "-NoProfile", "-NonInteractive",
      "-File",
      "${replace(get_parent_terragrunt_dir(), "\\", "/")}/scripts/Enable-PostHelper-RemoteBackend-Access.ps1"
    ]

    run_on_error = false
  }
}

inputs = {
  # load merged vnet artefact objects
  virtual_network_definitions = local.virtualNetwork_definition_merged

  # define which artefacts from the libraries we need to create
  virtual_network_artefact_names = [
    "l0-launchpad-main"
  ]

  launchpad_backend_type_previous_run = try({
    for key, val in local.bootstrap_helper_output.backend_storage_accounts : key => {
      backend_type    = val.ecp_terraform_backend
      apply_timestamp = val.ecp_terraform_backend_apply_timestamp
    }
    }, {
    "l0" = {
      backend_type = "local"
    },
    "l1" = {
      backend_type = "local"
    },
    "l2" = {
      backend_type = "local"
    }
  })
}
