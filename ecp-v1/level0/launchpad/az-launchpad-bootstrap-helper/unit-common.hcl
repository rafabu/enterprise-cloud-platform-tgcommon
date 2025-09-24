locals {
  ecp_deployment_unit = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-bootstrap-helper"
}

# helper module does not need a backend; can and should run with local state (as it is stateless anyway)
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = null
}

terraform {
# read helper module's output and prepare bootstrap state-specific environment variables.
  after_hook "get-backend-details-plan" {
    commands     = ["plan"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
$env:ecp_backend_resource_group_id = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_resource_group.value.id
$env:ecp_backend_storage_account_l0_id = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_storage_accounts.value.l0.id
SCRIPT
    ]
    run_on_error = false
  }
  after_hook "get-backend-details-apply" {
    commands     = ["apply"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
$env:ecp_backend_resource_group_id = (terraform output -json backend_resource_group | ConvertFrom-Json).id
$env:ecp_backend_storage_account_l0_id = (terraform output -json backend_storage_accounts | ConvertFrom-Json).l0.id
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
}
