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
$ecp_backend_resource_group = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_resource_group.value.id
$ecp_backend_storage_account_l0 = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_storage_accounts.value.l0.id
$filePath = Join-Path (Get-Location) "backend-details.json"
$json = @{
  "ecp_backend_resource_group" = $ecp_backend_resource_group;
  "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0;
} | ConvertTo-Json -Depth 3
Write-Output "Writing backend-details.json with (future) backend storage account details"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
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
$ecp_backend_resource_group = (terraform output -json backend_resource_group | ConvertFrom-Json).id
$ecp_backend_storage_account_l0 = (terraform output -json backend_storage_accounts | ConvertFrom-Json).l0.id
$filePath = Join-Path (Get-Location) "backend-details.json"
$json = @{
  "ecp_backend_resource_group" = $ecp_backend_resource_group;
  "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0;
} | ConvertTo-Json -Depth 3
Write-Output "Writing backend-details.json with (future) backend storage account details"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
}
