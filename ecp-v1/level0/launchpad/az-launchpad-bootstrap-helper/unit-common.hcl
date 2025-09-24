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
  before_hook "get-actor-context" {
    commands     = ["plan"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
##### Network Context #####
try{
  $privateIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias `
    (Get-NetIPConfiguration | Where-Object { $_.IPv4Address -and -not $_.NetAdapter.Status -eq "Disconnected" } |
      Select-Object -First 1 -ExpandProperty InterfaceAlias) |
        Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
          Select-Object -First 1 -ExpandProperty IPAddress)
  } catch {
    Write-Host "Get-NetIPAddress failed, falling back to .net method"
  }
if (-not $privateIP) {
  # Cross-platform fallback using .NET
  $privateIP = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()).IPAddressToString |
    Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -ne '127.0.0.1' } |
    Select-Object -First 1
}

# Get public IPv4 address from an external service
$publicIP = (Invoke-RestMethod -UseBasicParsing -Uri "https://api.ipify.org")

$filePath = Join-Path (Get-Location) "actor-network-details.json"
$json = @{
  "actor_public_ip" = $publicIP;
  "actor_private_ip" = $privateIP;
} | ConvertTo-Json -Depth 3
Write-Output "Writing actor-network-details.json with details on the actor's context"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
SCRIPT
    ]
    run_on_error = false
  }
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
  "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0
} | ConvertTo-Json -Depth 3
Write-Output "Writing backend-details.json with (future) backend storage account details"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force

$actor_identity =  @{ 
  object_id       = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.object_id;
  display_name    = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.display_name;
  type            = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.type;
  is_ecp_identity = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.is_ecp_launchpad_identity
  }

$filePath = Join-Path (Get-Location) "actor-identity-details.json"
$json = @{
  "actor_identity" = $actor_identity
} | ConvertTo-Json -Depth 3
Write-Output "Writing actor-identity-details.json with details on the actor's identity"
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
  "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0
} | ConvertTo-Json -Depth 3
Write-Output "Writing backend-details.json with (future) backend storage account details"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force

$actor_identity =  @{ 
  object_id       = (terraform output -json actor_identity | ConvertFrom-Json).object_id;
  display_name    = (terraform output -json actor_identity | ConvertFrom-Json).display_name;
  type            = (terraform output -json actor_identity | ConvertFrom-Json).type;
  is_ecp_identity = (terraform output -json actor_identity | ConvertFrom-Json).is_ecp_launchpad_identity
  }

$filePath = Join-Path (Get-Location) "actor-identity-details.json"
$json = @{
  "actor_identity" = $actor_identity
} | ConvertTo-Json -Depth 3
Write-Output "Writing actor-identity-details.json with details on the actor's identity"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
}
