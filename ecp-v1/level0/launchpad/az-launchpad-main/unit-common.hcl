dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
}

locals {
  ecp_deployment_unit = "main"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-main"

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
 backend = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true ? "azurerm" : "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true ? {
    subscription_id      = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].name
    container_name       = dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : null
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {
# assure storage account firewall access
  before_hook "Set-RemoteBackend-Access" {
    commands     = ["init", "plan", "apply"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     temporarily(!) open up access for the duration of this run
# Write-Output "ecp_resource_exists: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}"
# Write-Output "public_ip: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}"
# Write-Output "ip_within_ecp_launchpad: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad}"
# Write-Output "object_id: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.object_id}"
# Write-Output "is_ecp_launchpad_identity: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.is_ecp_launchpad_identity}"

$resourceExists = ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}
$ipInRange = ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad}
$publicIp = ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}
$subscriptionId = ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].subscription_id}
$accountName = ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].name}

if ($true -eq $resourceExists -and $false -eq $ipInRange -and $publicIp -ne $null) {
  Write-Output "➕ Adding IP $publicIp to Storage Account $accountName..."
  # Get current allowed IPs
  $rules = az storage account network-rule list `
    --subscription $subscriptionId `
    --account-name $accountName `
    --query "ipRules[].ipAddressOrRange" `
    -o tsv
  if ($rules -contains $publicIp) {
    Write-Output "✅ IP $publicIp is already allowed on $accountName."
  }
  else {
    Write-Output "➕ Adding IP $publicIp to Storage Account $accountName..."
    # az storage account network-rule add `
    #   --subscription $subscriptionId `
    #   --account-name $accountName `
    #   --ip-address $IpAddress | Out-Null
    Write-Output "➕ Adding IP $publicIp to Storage Account $accountName..."
  }
elseif($true -eq $ipInRange) {
  Write-Output "✅ Private IP is in launchpad vnet range; no need to add public IP to Storage Account $accountName."
}
elseif ($false -eq $resourceExists) {
  write-OUtput "⚠️  Storage Account $accountName does not exist yet; no need to add IP $publicIp."
}
else {
  Write-Output "⚠️  No public IP available; cannot add to Storage Account $accountName."
}
SCRIPT
    ]
    run_on_error = false
  }

  after_hook "Close-RemoteBackend-Access" {
    commands     = ["init", "plan", "apply"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     always(!) need to remove access again --> run_on_error = true
Write-Output "ecp_resource_exists: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}"
Write-Output "public_ip: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}"
Write-Output "ip_within_ecp_launchpad: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad}"
Write-Output "object_id: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.object_id}"
Write-Output "is_ecp_launchpad_identity: ${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.is_ecp_launchpad_identity}"
SCRIPT
    ]
    # run regardless of whether the terraform command failed
    run_on_error = true
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
}
