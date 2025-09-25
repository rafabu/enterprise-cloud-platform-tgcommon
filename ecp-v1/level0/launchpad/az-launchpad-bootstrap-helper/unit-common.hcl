#
# Helper config which extracts runtime information via terraform data sources and
#     drops them into local JSON files for consumption by scripts and other tools
#     downstream
#

locals {
  ecp_deployment_unit = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-bootstrap-helper"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"

################# virtual network artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworks_path_shared = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworks"
  library_virtualNetworks_path_unit= "${local.library_path_unit}/virtualNetworks"
  library_virtualNetworks_filter = "*.virtualNetwork.json"
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
      if (contains(keys(local.virtualNetwork_definition_exclude_unit), key) == false)
    },
    local.virtualNetwork_definition_unit
  )
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
#   before_hook "get-actor-network-context" {
#     commands     = ["plan", "apply"]
#     execute      = [
#       "pwsh",
#       "-Command", 
# <<-SCRIPT
# ##### Network Context #####
# try{
#   $privateIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias `
#     (Get-NetIPConfiguration | Where-Object { $_.IPv4Address -and -not $_.NetAdapter.Status -eq "Disconnected" } |
#       Select-Object -First 1 -ExpandProperty InterfaceAlias) |
#         Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
#           Select-Object -First 1 -ExpandProperty IPAddress)
#   } catch {
#     Write-Host "Get-NetIPAddress failed, falling back to .net method"
#   }
# if (-not $privateIP) {
#   # Cross-platform fallback using .NET
#   $privateIP = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()).IPAddressToString |
#     Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -ne '127.0.0.1' } |
#     Select-Object -First 1
# }

# # Get public IPv4 address from an external service
# $publicIP = (Invoke-RestMethod -UseBasicParsing -Uri "https://api.ipify.org")

# $filePath = Join-Path (Get-Location) "lp-bootstrap-actor-network-details.json"
# $json = @{
#   "actor_public_ip" = $publicIP;
#   "actor_private_ip" = $privateIP;
# } | ConvertTo-Json -Depth 3
# Write-Output "Writing lp-bootstrap-actor-network-details.json with details on the actor's context"
# Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
# SCRIPT
#     ]
#     run_on_error = false
#   }
# read helper module's output and prepare bootstrap state-specific environment variables.
  after_hook "get-backend-details" {
    commands     = ["plan", "apply"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT

# backend strorage account details
if ($env:TG_CTX_COMMAND == "plan") {
  $ecp_backend_resource_group = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_resource_group.value.id
  $ecp_backend_storage_account_l0 = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_storage_accounts.value.l0.id
  $ecp_backend_storage_account_exists = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.backend_storage_accounts.value.l0.ecp_resource_exists
}
elseif ($env:TG_CTX_COMMAND -eq "apply") {
  $ecp_backend_resource_group = (terraform output -json backend_resource_group | ConvertFrom-Json).id
  $ecp_backend_storage_account_l0 = (terraform output -json backend_storage_accounts | ConvertFrom-Json).l0.id
  $ecp_backend_storage_account_exists = (terraform output -json backend_storage_accounts | ConvertFrom-Json).l0.ecp_resource_exists
}
else {
  Write-Error "TG_CTX_COMMAND environment variable is not set to 'plan' or 'apply'. Cannot determine the correct way to extract outputs."
  exit 1
}
$filePath = Join-Path (Get-Location) "lp-bootstrap-backend-details.json"
$json = @{
  "ecp_backend_resource_group" = $ecp_backend_resource_group;
  "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0
  "ecp_backend_storage_account_exists" = $ecp_backend_storage_account_exists
} | ConvertTo-Json -Depth 3
Write-Output "Writing lp-bootstrap-backend-details.json with (future) backend storage account details"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force

# actor identity details
if ($env:TG_CTX_COMMAND -eq "plan") {
$actor_identity =  @{ 
  object_id       = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.object_id;
  display_name    = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.display_name;
  type            = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.type;
  is_ecp_identity = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs.actor_identity.value.is_ecp_launchpad_identity
  }
}
elseif ($env:TG_CTX_COMMAND -eq "apply") {
$actor_identity =  @{ 
  object_id       = (terraform output -json actor_identity | ConvertFrom-Json).object_id;
  display_name    = (terraform output -json actor_identity | ConvertFrom-Json).display_name;
  type            = (terraform output -json actor_identity | ConvertFrom-Json).type;
  is_ecp_identity = (terraform output -json actor_identity | ConvertFrom-Json).is_ecp_launchpad_identity
  }
}
else {
  Write-Error "TG_CTX_COMMAND environment variable is not set to 'plan' or 'apply'. Cannot determine the correct way to extract outputs."
  exit 1
}
$filePath = Join-Path (Get-Location) "lp-bootstrap-actor-identity-details.json"
$json = $actor_identity | ConvertTo-Json -Depth 3
Write-Output "Writing lp-bootstrap-actor-identity-details.json with details on the actor's identity"
Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
SCRIPT
    ]
    run_on_error = false
  }
#   after_hook "get-backend-details-apply" {
#     commands     = ["apply"]
#     execute      = [
#       "pwsh",
#       "-Command", 
# <<-SCRIPT
# $ecp_backend_resource_group = (terraform output -json backend_resource_group | ConvertFrom-Json).id
# $ecp_backend_storage_account_l0 = (terraform output -json backend_storage_accounts | ConvertFrom-Json).l0.id

# $filePath = Join-Path (Get-Location) "lp-bootstrap-backend-details.json"
# $json = @{
#   "ecp_backend_resource_group" = $ecp_backend_resource_group;
#   "ecp_backend_storage_account_l0" = $ecp_backend_storage_account_l0
# } | ConvertTo-Json -Depth 3
# Write-Output "Writing lp-bootstrap-backend-details.json with (future) backend storage account details"
# Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force

# $actor_identity =  @{ 
#   object_id       = (terraform output -json actor_identity | ConvertFrom-Json).object_id;
#   display_name    = (terraform output -json actor_identity | ConvertFrom-Json).display_name;
#   type            = (terraform output -json actor_identity | ConvertFrom-Json).type;
#   is_ecp_identity = (terraform output -json actor_identity | ConvertFrom-Json).is_ecp_launchpad_identity
#   }

# $filePath = Join-Path (Get-Location) "lp-bootstrap-actor-identity-details.json"
# $json = $actor_identity | ConvertTo-Json -Depth 3
# Write-Output "Writing lp-bootstrap-actor-identity-details.json with details on the actor's identity"
# Set-Content -Path $filePath -Value $json -Encoding UTF8 -Force
# SCRIPT
#     ]
#     run_on_error = false
#   }
# }

inputs = {
   # load merged vnet artefact objects
  virtual_network_definitions = local.virtualNetwork_definition_merged
 
  # define which artefacts from the libraries we need to create
  virtual_network_artefact_names = [
    "l0-launchpad-main"
  ]
}
