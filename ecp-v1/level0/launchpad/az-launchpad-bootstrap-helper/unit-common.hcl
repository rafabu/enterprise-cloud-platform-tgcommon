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

# helper module does not need a backend; can and should run with local state (as it is kind ofstateless anyway)
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = null
}

terraform {

after_hook "Set-RemoteBackend-Access" {
    commands     = [
      "apply",
      # "destroy",  # during destroy the remote state should no longer be present
      # "force-unlock",
      "import",
      "init", 
      # "output",
      "plan", 
      "refresh",
      # "state",
      # "taint",
      # "untaint",
      # "validate"
      ]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

$tgWriteCommands = @(
  "apply",
  "destroy",
  "force-unlock",
  "import",
  "refresh",
  "taint",
  "untaint"
)

if ($tgWriteCommands -inotcontains $env:TG_CTX_COMMAND) {
    $planOutput = (terraform show -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json).planned_values.outputs

    $resourceExists = if ($planOutput.backend_storage_accounts.value.l0.ecp_resource_exists -eq "true") { $true } else { $false }
    $ipInRange = if ($planOutput.actor_network_information.value.is_local_ip_within_ecp_launchpad -eq "true") { $true } else { $false }
    $publicIp = $planOutput.actor_network_information.value.public_ip
    $subscriptionId = $planOutput.backend_storage_accounts.value.l0.subscription_id
    $accountName = $planOutput.backend_storage_accounts.value.l0.name

    $objectId = $planOutput.actor_identity.value.object_id
    $ecpIdentity = if ("true" -eq $planOutput.actor_identity.value.is_ecp_launchpad_identity -eq $true) { $true } else { $false }
    $principalType = if ("user" -eq $planOutput.actor_identity.value.type) { "User" } else { "ServicePrincipal" }
    $roleName = "Storage Blob Data Reader"

}
else {
    $applyOutput = terraform output -json | ConvertFrom-Json
    
    $resourceExists = if ($applyOutput.backend_storage_accounts.value.l0.ecp_resource_exists -eq "true") { $true } else { $false }
    $ipInRange = if ($applyOutput.actor_network_information.value.is_local_ip_within_ecp_launchpad -eq "true") { $true } else { $false }
    $publicIp = $applyOutput.actor_network_information.value.public_ip
    $subscriptionId = $applyOutput.backend_storage_accounts.value.l0.subscription_id
    $accountName = $applyOutput.backend_storage_accounts.value.l0.name

    $objectId = $applyOutput.actor_identity.value.object_id;
    $ecpIdentity = if ("true" -eq $applyOutput.actor_identity.value.is_ecp_launchpad_identity -eq $true) { $true } else { $false }
    $principalType = if ("user" -eq $applyOutput.actor_identity.value.type) { "User" } else { "ServicePrincipal" }
    $roleName = "Storage Blob Data Contributor"
}

# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     temporarily(!) open up access for the duration of this run
#     plus RBAC permissions if not using ECP Identity

if ($true -eq $resourceExists) {
    Write-Output "INFO: Storage Account should exist; querying"
    $sa = az storage account show `
        --subscription $subscriptionId `
        --name $accountName `
        -o json | ConvertFrom-Json
    Write-Output ""

    Write-Output "##### network access #####"
    if ($true -eq $resourceExists -and $false -eq $ipInRange -and $publicIp -ne $null) {
        Write-Output "INFO: Checking Storage Account $accountName for public IP $publicIp access..."
        if ($sa.publicNetworkAccess -ne "Enabled") {
            Write-Output "     Public network access is $($sa.publicNetworkAccess). Enabling..."
            az storage account update `
                --subscription $subscriptionId `
                --name $accountName `
                --public-network-access Enabled | Out-Null
        }
        else {
            Write-Output "     Public network access is already Enabled."
        }
        # Get current allowed IPs
        $rules = az storage account network-rule list `
            --subscription $subscriptionId `
            --account-name $accountName `
            --query "ipRules[].ipAddressOrRange" `
            -o tsv
        if ($rules -contains $publicIp) {
            Write-Output "     IP $publicIp is already allowed per network-rule of storage account $accountName."
        }
        else {
            Write-Output "     IP $publicIp is being added to network-rule of storage account $accountName..."
            az storage account network-rule add `
                --subscription $subscriptionId `
                --account-name $accountName `
                --ip-address $publicIp | Out-Null
            Write-Output "     added..."
            $waitNeeded = $true
        }
    }
    elseif ($true -eq $ipInRange) {
        Write-Output "INFO: Private IP is in launchpad vnet range; no need to add public IP to Storage Account $accountName."
    }
    elseif ($publicIp -eq $null) {
        Write-Output "WARNING: No public IP available; cannot add to Storage Account $accountName."
    }
    elseif ($false -eq $resourceExists) {
        Write-Output "WARNING: Storage Account $accountName does not exist yet; no need to add IP $publicIp."
    }
    Write-Output ""

    Write-Output "##### Blob Access #####"
    if ($false -eq $ecpIdentity) {
        Write-Output "INFO: No ECP Identity provided; checking role assignment."
        $assignment = az role assignment list `
            --subscription $subscriptionId `
            --assignee-object-id $objectId `
            --role "$roleName" `
            --scope $sa.id `
            -o tsv

        if ($assignment) {
            Write-Host "    Identity $objectId already has role '$roleName' on $accountName (terraform command: '$env:TG_CTX_COMMAND')"
        }
        else {
            Write-Host "     Assigning role '$roleName' to $objectId on $accountName..."
            az role assignment create `
                --subscription $subscriptionId `
                --description "ECP_BOOTSTRAP_HELPER" `
                --assignee-object-id $objectId `
                --assignee-principal-type $principalType `
                --role "$roleName" `
                --scope $sa.id | Out-Null
            Write-Output "     added..."
            $waitNeeded = $true
        }
    }
    else {
        Write-Output "INFO: ECP Identity provided; assuming it has sufficient access."
    }
}
else {
    Write-Output "INFO: Storage Account does not exist yet; cannot configure access."
}
Write-Output ""
if ($waitNeeded) {
    Write-Output "INFO: Waiting 60 seconds for changes to propagate..."
    Start-Sleep -Seconds 60
}
SCRIPT
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
}
