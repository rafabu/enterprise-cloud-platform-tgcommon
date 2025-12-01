#
# Helper config which extracts runtime information via terraform data sources and
#     drops them into local JSON files for consumption by scripts and other tools
#     downstream
#

locals {
  ecp_deployment_unit             = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-bootstrap-helper"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit   = "${get_terragrunt_dir()}/lib"

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
TG_DOWNLOAD_DIR = (
  get_env("TG_DOWNLOAD_DIR", "") != "" ? get_env("TG_DOWNLOAD_DIR") :
  get_env("RUNNER_TEMP", "") != "" ? get_env("RUNNER_TEMP") :
  get_env("AGENT_TEMPDIRECTORY", "") != "" ? get_env("AGENT_TEMPDIRECTORY") :
  get_env("TMPDIR", "") != "" ? get_env("TMPDIR") :
  get_env("TEMP", "") != "" ? get_env("TEMP") :
  "/tmp"
)
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", basename(get_original_terragrunt_dir()))}"
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
      "-Command",
      <<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
$systemTempPath = [System.IO.Path]::GetTempPath()
if ($env:TG_DOWNLOAD_DIR) {
    $tempPath = $env:TG_DOWNLOAD_DIR
}
else {
    $tempPath = $systemTempPath
}
$out_path = [System.IO.Path]::Combine($tempPath, "${uuidv5("dns", basename(get_original_terragrunt_dir()))}")
if (-not (Test-Path -Path $out_path -PathType Container)) {
    New-Item -ItemType Directory -Path $out_path -Force | Out-Null
}
SCRIPT
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
      "-Command",
      <<-SCRIPT
function Merge-Objects {
    param (
        [object]$Object1,
        [object]$Object2
    )
    $merged = [ordered]@{}
    foreach ($prop in $Object1.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    foreach ($prop in $Object2.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    return [PSCustomObject]$merged
}

Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
$systemTempPath = [System.IO.Path]::GetTempPath()
if ($env:TG_DOWNLOAD_DIR) {
    $tempPath = $env:TG_DOWNLOAD_DIR
}
else {
    $tempPath = $systemTempPath
}
$out_path = [System.IO.Path]::Combine($tempPath, "${uuidv5("dns", basename(get_original_terragrunt_dir()))}")

# backend storage account details
if ($env:TG_CTX_COMMAND -eq "plan") {
    # "plan" like command - need to parse the tfplan file and build an apply-like output
    $tfPlanOutput = (terraform show -no-color -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json)

    # actor_identity
    $tfOutputAIPlanned  =  $tfPlanOutput.planned_values.outputs.actor_identity.value
    $tfOutputAIAfter = $tfPlanOutput.output_changes.actor_identity.after
    $tfOutputAIAfterUnknown =$tfPlanOutput.output_changes.actor_identity.after_unknown
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIAfterUnknown -Object2 $tfOutputAIAfter
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIMerged -Object2 $tfOutputAIPlanned

    # actor_network_information
    $tfOutputANPlanned  =  $tfPlanOutput.planned_values.outputs.actor_network_information.value
    $tfOutputANAfter = $tfPlanOutput.output_changes.actor_network_information.after
    $tfOutputANAfterUnknown =$tfPlanOutput.output_changes.actor_network_information.after_unknown
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANAfterUnknown -Object2 $tfOutputANAfter
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANMerged -Object2 $tfOutputANPlanned
    
    # backend_resource_group
    $tfOutputBRGPlanned  =  $tfPlanOutput.planned_values.outputs.backend_resource_group.value
    $tfOutputBRGAfter = $tfPlanOutput.output_changes.backend_resource_group.after
    $tfOutputBRGAfterUnknown =$tfPlanOutput.output_changes.backend_resource_group.after_unknown
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGAfterUnknown -Object2 $tfOutputBRGAfter
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGMerged -Object2 $tfOutputBRGPlanned

    # backend_storage_accounts
    $tfOutputBSPlanned  =  $tfPlanOutput.planned_values.outputs.backend_storage_accounts.value
    $tfOutputBSAfter = $tfPlanOutput.output_changes.backend_storage_accounts.after
    $tfOutputBSAfterUnknown =$tfPlanOutput.output_changes.backend_storage_accounts.after_unknown
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSAfterUnknown -Object2 $tfOutputBSAfter
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSMerged -Object2 $tfOutputBSPlanned

    $terraform_output = @{
        "actor_identity"            = @{
          "value" = $tfOutputAIMerged
          };
        "actor_network_information" = @{
          "value" = $tfOutputANMerged
          };
        "backend_resource_group"    = @{
          "value" = $tfOutputBRGMerged
          };
        "backend_storage_accounts"  = @{
          "value" = $tfOutputBSMerged
          }
    }
}
elseif ($env:TG_CTX_COMMAND -eq "apply") {
    $terraform_output = terraform output -json | ConvertFrom-Json
}

$filePath = Join-Path $out_path "terraform_output.json"
$terraform_output_json = @{
    "actor_identity"            = $terraform_output.actor_identity.value
    "actor_network_information" = $terraform_output.actor_network_information.value
    "backend_storage_accounts"  = $terraform_output.backend_storage_accounts.value
} | ConvertTo-Json -Depth 5

Write-Output "    Writing $filePath with module's output"
Set-Content -Path $filePath -Value $terraform_output_json -Encoding UTF8 -Force
SCRIPT
    ]
    run_on_error = false
  }

  # enable remote backend access if conditions are met:
  #    - storage account exists
  #    - actor IP is outside of launchpad vnet range
  #    - actor identity is not the ECP Identity (which should have access anyway)
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
      "-Command",
      <<-SCRIPT
function Merge-Objects {
    param (
        [object]$Object1,
        [object]$Object2
    )
    $merged = [ordered]@{}
    foreach ($prop in $Object1.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    foreach ($prop in $Object2.PSObject.Properties) {
        $merged[$prop.Name] = $prop.Value
    }
    return [PSCustomObject]$merged
}

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
    # "plan" like command - need to parse the tfplan file and build an apply-like output
    $tfPlanOutput = (terraform show -no-color -json az-launchpad-bootstrap-helper.tfplan | ConvertFrom-Json)

    # actor_identity
    $tfOutputAIPlanned  =  $tfPlanOutput.planned_values.outputs.actor_identity.value
    $tfOutputAIAfter = $tfPlanOutput.output_changes.actor_identity.after
    $tfOutputAIAfterUnknown =$tfPlanOutput.output_changes.actor_identity.after_unknown
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIAfterUnknown -Object2 $tfOutputAIAfter
    $tfOutputAIMerged = Merge-Objects -Object1 $tfOutputAIMerged -Object2 $tfOutputAIPlanned

    # actor_network_information
    $tfOutputANPlanned  =  $tfPlanOutput.planned_values.outputs.actor_network_information.value
    $tfOutputANAfter = $tfPlanOutput.output_changes.actor_network_information.after
    $tfOutputANAfterUnknown =$tfPlanOutput.output_changes.actor_network_information.after_unknown
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANAfterUnknown -Object2 $tfOutputANAfter
    $tfOutputANMerged = Merge-Objects -Object1 $tfOutputANMerged -Object2 $tfOutputANPlanned
    
    # backend_resource_group
    $tfOutputBRGPlanned  =  $tfPlanOutput.planned_values.outputs.backend_resource_group.value
    $tfOutputBRGAfter = $tfPlanOutput.output_changes.backend_resource_group.after
    $tfOutputBRGAfterUnknown =$tfPlanOutput.output_changes.backend_resource_group.after_unknown
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGAfterUnknown -Object2 $tfOutputBRGAfter
    $tfOutputBRGMerged = Merge-Objects -Object1 $tfOutputBRGMerged -Object2 $tfOutputBRGPlanned

    # backend_storage_accounts
    $tfOutputBSPlanned  =  $tfPlanOutput.planned_values.outputs.backend_storage_accounts.value
    $tfOutputBSAfter = $tfPlanOutput.output_changes.backend_storage_accounts.after
    $tfOutputBSAfterUnknown =$tfPlanOutput.output_changes.backend_storage_accounts.after_unknown
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSAfterUnknown -Object2 $tfOutputBSAfter
    $tfOutputBSMerged = Merge-Objects -Object1 $tfOutputBSMerged -Object2 $tfOutputBSPlanned

    $tfOutput = @{
        "actor_identity"            = @{
          "value" = $tfOutputAIMerged
          };
        "actor_network_information" = @{
          "value" = $tfOutputANMerged
          };
        "backend_resource_group"    = @{
          "value" = $tfOutputBRGMerged
          };
        "backend_storage_accounts"  = @{
          "value" = $tfOutputBSMerged
          }
    }
}
else {
    # "apply" like command - write access is required
    $tfOutput = terraform output -json | ConvertFrom-Json
}

$resourceExists = if ($tfOutput.backend_storage_accounts.value.l0.ecp_resource_exists -eq "true") { $true } else { $false }
$ipInRange = if ($tfOutput.actor_network_information.value.is_local_ip_within_ecp_launchpad -eq "true") { "true" } else { "false" }
$localIp = $tfOutput.actor_network_information.value.local_ip
$publicIp = $tfOutput.actor_network_information.value.public_ip
$subscriptionId = $tfOutput.backend_storage_accounts.value.l0.subscription_id
$accountName = $tfOutput.backend_storage_accounts.value.l0.name

$roleName = "Storage Blob Data Contributor"

$objectId = $tfOutput.actor_identity.value.object_id
$displayName = $tfOutput.actor_identity.value.display_name
$ecpIdentity = if ("true" -eq $tfOutput.actor_identity.value.is_ecp_launchpad_identity -eq $true) { $true } else { $false }
$principalType = if ("user" -eq $tfOutput.actor_identity.value.type) { "User" } else { "ServicePrincipal" }

# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     temporarily(!) open up access for the duration of this run
#     plus RBAC permissions if not using ECP Identity
if ($true -eq $resourceExists) {
    Write-Output "INFO: Storage Account $accountName exists; querying"
    $sa = az storage account show `
        --subscription $subscriptionId `
        --name $accountName `
        -o json | ConvertFrom-Json
    Write-Output ""

    Write-Output "##### network access #####"
    if ($true -eq $resourceExists -and "false" -eq $ipInRange -and $null -ne $publicIp) {
        Write-Output "INFO: Local IP is $localIp is not in launchpad range - checking if access to storage account $accountName via public IP $publicIp is allowed..."
        if ($sa.publicNetworkAccess -ne "Enabled") {
            Write-Output "     Public network access is $($sa.publicNetworkAccess). Enabling..."
            az storage account update `
                --subscription $subscriptionId `
                --name $accountName `
                --public-network-access Enabled | Out-Null
        }
        else {
            Write-Output "     public network access is already Enabled. No change needed."
        }
        # Get current allowed IPs
        $rules = az storage account network-rule list `
            --subscription $subscriptionId `
            --account-name $accountName `
            --query "ipRules[].ipAddressOrRange" `
            -o tsv
        if ($rules -contains $publicIp) {
            Write-Output "     IP $publicIp is already allowed per network-rule of storage account $accountName. No change needed."
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
    elseif ("true" -eq $ipInRange) {
        Write-Output "INFO: Private IP $localIp is in launchpad vnet range; no need to add public IP to Storage Account $accountName."
    }
    elseif ($null -eq $publicIp) {
        Write-Output "WARNING: No public IP available; cannot add to Storage Account $accountName."
    }
    elseif ($false -eq $resourceExists) {
        Write-Output "WARNING: Storage Account $accountName does not exist yet; cannot configure network access."
    }
    Write-Output ""

    Write-Output "##### Blob Access #####"
    if ($false -eq $ecpIdentity) {
        Write-Output "INFO: identity $displayName isn't an ECP Identity; checking its '$roleName' assignment on $accountName."
        $assignment = az role assignment list `
            --subscription $subscriptionId `
            --assignee-object-id $objectId `
            --role "$roleName" `
            --scope $sa.id `
            -o tsv

        if ($assignment) {
            Write-Host "    identity $displayName already has role '$roleName' on $accountName (terraform command: '$env:TG_CTX_COMMAND')"
        }
        else {
            Write-Host "     assigning role '$roleName' to $displayName on $accountName..."
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
        Write-Output "INFO: Running with ECP Identity $displayName; assuming it has sufficient access. No change needed."
    }
}
else {
    Write-Output "INFO: Storage Account $accountName does not exist yet; cannot configure access. Will have to run on local terraform backend for now."
}
Write-Output ""
if ($waitNeeded) {
    Write-Output "INFO: Sleep 60 seconds for RBAC and/or SA port rule changes to propagate on $accountName"
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
