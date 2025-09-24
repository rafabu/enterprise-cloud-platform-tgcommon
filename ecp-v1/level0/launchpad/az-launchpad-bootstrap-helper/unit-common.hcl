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
  after_hook "get-backend-details" {
    commands     = ["apply", "plan", "destroy"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output """$env:TG_CTX_TF_PATH"" output -json backend_resource_group"

SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
}
