dependencies {
  paths = [
    format("%s/../../bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir()),
    format("%s/../ado-repo-sync", get_original_terragrunt_dir())
  ]
}

dependency "l0-lp-az-lp-main" {
  config_path = format("%s/../../launchpad/az-launchpad-main", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    ecp_environment_name = "mock-environment"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_unit             = "ado-automation"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-pipeline"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit   = "${get_terragrunt_dir()}/lib"

  ecp_environment_name = dependency.l0-lp-az-lp-main.outputs.ecp_environment_name

  ################# ADO pipeline artefacts #################
  # exclude the ones named in the *.exclude.json
  # artefact schema follows: https://learn.microsoft.com/en-us/rest/api/azure/devops/build/definitions/create?view=azure-devops-rest-7.1#buildprocess
  library_buildDefinition_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure-devops/yaml-pipeline"
  library_buildDefinition_path_unit      = "${local.library_path_unit}/yaml-pipeline"
  library_buildDefinition_filter         = "*.buildDefinition.json"
  library_buildDefinition_exclude_filter = "*.buildDefinition.exclude.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  buildDefinition_definition_shared = try({
    for fileName in fileset(local.library_buildDefinition_path_shared, local.library_buildDefinition_filter) : jsondecode(file(format("%s/%s", local.library_buildDefinition_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_buildDefinition_path_shared, fileName)))
  }, {})
  buildDefinition_definition_unit = try({
    for fileName in fileset(local.library_buildDefinition_path_unit, local.library_buildDefinition_filter) : jsondecode(file(format("%s/%s", local.library_buildDefinition_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_buildDefinition_path_unit, fileName)))
  }, {})
  buildDefinition_definition_exclude_unit = try({
    for fileName in fileset(local.library_buildDefinition_path_unit, local.library_buildDefinition_exclude_filter) : jsondecode(file(format("%s/%s", local.library_buildDefinition_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_buildDefinition_path_unit, fileName)))
  }, {})
  buildDefinition_definition_merged = merge(
    {
      for key, val in local.buildDefinition_definition_shared : key => val
      if(contains(keys(local.buildDefinition_definition_exclude_unit), key) == false)
    },
    local.buildDefinition_definition_unit
  )

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR                = get_env("TG_DOWNLOAD_DIR", trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-Command", "[System.IO.Path]::GetTempPath()")))
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type         = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true ? "azurerm" : "local", "local")
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

  ################# tags #################
  unit_common_azure_tags = {
    # "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
  backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.bootstrap_backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    path = local.bootstrap_local_backend_path
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {

  before_hook "reconfigure-backend" {
    commands = [
      "init",
      "plan",
      "apply",
      "destroy"
    ]
    execute = [
      "pwsh",
      "-Command",
      <<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

Write-Output "     running 'terraform init -reconfigure'"  
terraform init -reconfigure | Out-Null
SCRIPT
    ]
    run_on_error = false
  }

  before_hook "Copy-TerraformStateToRemote" {
    commands = [
      "apply",
      # "destroy",  # child of az-launchpad-backend: no need to migrate back to local state during destroy
      # "force-unlock",
      "import",
      "init", # on initial run, no outputs will be available, yet
      "output",
      "plan",
      "refresh",
      "state",
      "taint",
      "untaint",
      "validate"
    ]
    execute = [
      "pwsh",
      "-Command",
      <<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
Write-Output "INFO: bootstrap_backend_type: '${local.bootstrap_backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
    if ("azurerm" -eq "${local.bootstrap_backend_type}") {
        if (Test-Path "${local.bootstrap_local_backend_path}") {
            Write-Output "      remote backend changed from 'local' to 'azurerm'; copying local state to remote now..."
            Write-Output "      uploading '${local.bootstrap_local_backend_path}' to '${basename(path_relative_to_include())}.tfstate' on ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")}'"  
            $uploadResult = az storage blob upload --account-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].name, "unknown storage account")} --container-name ${try(local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container, "unknown container")} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Output "      state file uploaded successfully to remote backend"
                terraform init -migrate-state | Out-Null
                Write-Output "      removing local state file '${local.bootstrap_local_backend_path}'"
                Move-Item -Path "${local.bootstrap_local_backend_path}" -Destination "${local.bootstrap_local_backend_path}.backup" -Force -ErrorAction SilentlyContinue
            } else {
                Write-Error "      failed to upload state file to remote backend. Error: $uploadResult"
                throw "State file upload failed with exit code: $LASTEXITCODE"
            }
        }
        else {
            Write-Output "      local state file '${local.bootstrap_local_backend_path}' dos not exist; skipping upload to remote backend"
        }
    }
}
else {
    Write-Output "INFO: backend has not changed; no action required"
}
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags

  ado_yaml_pipeline_definitions = local.buildDefinition_definition_merged

  # define which artefacts from the libraries we need to create
  ado_yaml_pipeline_artefact_names = [
   "ECP-Deployment-Testing-Disabled",
   "ECP-Deployment-Testing-Enabled"
  ]

  ecp_environment_name = local.ecp_environment_name
}
