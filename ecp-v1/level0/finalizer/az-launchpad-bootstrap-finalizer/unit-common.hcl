dependencies{
   paths = [
    format("%s/../../bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir()),
    format("%s/../../launchpad/az-launchpad-main", get_original_terragrunt_dir()),
    format("%s/../../launchpad/az-launchpad-network", get_original_terragrunt_dir()),
    format("%s/../../launchpad/az-launchpad-backend", get_original_terragrunt_dir()),
    format("%s/../../launchpad/az-devcenter", get_original_terragrunt_dir()),
    format("%s/../../launchpad/ado-project", get_original_terragrunt_dir()),
    format("%s/../../automation/ado-pipeline", get_original_terragrunt_dir())
  ]
}

dependency "l0-lp-ado-mpool" {
  config_path = format("%s/../../launchpad/ado-mpool", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    managed_devops_pool = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevOps/managedDevOpsPools/mock-pool"
      id_azuredevops = "0"
      name = "mock-pool"
      resource_group_name = "mock-rg"
      location = "westeurope"
    }
     service_principals = {
      "l0-contribute" = {
        id   = "00000000-0000-0000-0000-000000000000"
        display_name = "mock_name"
        client_id = "00000000-0000-0000-0000-000000000000"
        object_id = "00000000-0000-0000-0000-000000000000"
        type = "managedIdentity"
      }
      "l0-read" = {
        id   = "00000000-0000-0000-0000-000000000000"
        display_name = "mock_name"
        client_id = "00000000-0000-0000-0000-000000000000"
        object_id = "00000000-0000-0000-0000-000000000000"
        type = "managedIdentity"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  azure_tf_module_folder = "launchpad-bootstrap-finalizer"

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )

  # see if backend variables are set
  backend_config_present = alltrue([
    get_env("ECP_TG_BACKEND_SUBSCRIPTION_ID", "") != "",
    get_env("ECP_TG_BACKEND_RESOURCE_GROUP_NAME", "") != "",
    get_env("ECP_TG_BACKEND_NAME", "") != "",
    get_env("ECP_TG_BACKEND_CONTAINER", "") != ""
  ])

  ################# bootstrap-helper unit output (fallback) #################
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(
    try(file("${local.bootstrap_helper_folder}/terraform_output.json"), "{}")
  )
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

  backend_type         = local.backend_config_present ? "azurerm" : try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true && get_terraform_command() != "destroy" ? "azurerm" : "local", "local")
  backend_config = local.backend_config_present ? {
    subscription_id      = get_env("ECP_TG_BACKEND_SUBSCRIPTION_ID")
    resource_group_name  = get_env("ECP_TG_BACKEND_RESOURCE_GROUP_NAME")
    storage_account_name = get_env("ECP_TG_BACKEND_NAME")
    container_name       = get_env("ECP_TG_BACKEND_CONTAINER")
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : local.backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
    } : {
    path = local.bootstrap_local_backend_path
  }

  ################# tags #################
  unit_common_azure_tags = {
    # "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
  backend = local.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.backend_config
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {

  before_hook "reconfigure-backend" {
    commands = [
      "init",
      # "plan",
      # "apply",
      # "destroy"
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
      # "destroy",  # during destroy the remote state should no longer be present
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
Write-Output "INFO: backend_type: '${local.backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
    if ("azurerm" -eq "${local.backend_type}") {
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
            Write-Output "      local state file '${local.bootstrap_local_backend_path}' does not exist; skipping upload to remote backend"
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

    after_hook "Close-RemoteBackend-Access" {
       commands     = [
        "apply",
        # "destroy",  # during destroy the remote state should no longer be present
        "force-unlock",
        "import",
        # "init", 
        # "output",
        # "plan", 
        # "refresh",
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
  # if not running from within launchpad network, access to backend will be blocked by storage account firewall
  #     always(!) need to remove access again --> run_on_error = true
  # remove temporary fw and RBAC again
  Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

  $resourceExists = if ("true" -eq "${local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true}") { $true } else { $false }
  $ipInRange = if ("true" -eq "${local.bootstrap_helper_output.actor_network_information.is_local_ip_within_ecp_launchpad == true}") { $true } else { $false }
  $publicIp = "${local.bootstrap_helper_output.actor_network_information.public_ip}"
  $subscriptionId = "${local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id}"
  $accountName = "${local.bootstrap_helper_output.backend_storage_accounts["l0"].name}"

  $objectId = "${local.bootstrap_helper_output.actor_identity.object_id}"
  $ecpIdentity = if ("true" -eq "${local.bootstrap_helper_output.actor_identity.is_ecp_launchpad_identity == true}") { $true } else { $false }

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
          # Get current allowed IPs
          $rules = az storage account network-rule list `
              --subscription $subscriptionId `
              --account-name $accountName `
              --query "ipRules[].ipAddressOrRange" `
              -o tsv
          if ($rules -contains $publicIp) {
               Write-Output "     Remove $publicIp from network-rule of storage account $accountName..."
              az storage account network-rule remove `
                  --subscription $subscriptionId `
                  --account-name $accountName `
                  --ip-address $publicIp | Out-Null
              Write-Output "     removed..."
          }
          else {
              Write-Output "    $publicIp not in network-rule of storage account $accountName."
          }
           if ($sa.publicNetworkAccess -eq "Enabled") {
              Write-Output "     Disable public network access again..."
              az storage account update `
                  --subscription $subscriptionId `
                  --name $accountName `
                  --public-network-access Disabled | Out-Null
          }
          else {
              Write-Output "     Public network access already disabled."
          }
      }
      elseif ($true -eq $ipInRange) {
          Write-Output "INFO: Private IP is in launchpad vnet range"
          Write-Output "INFO:     no need to remove network rule from Storage Account $accountName."
      }
      elseif ($publicIp -eq $null) {
          Write-Output "WARNING: No public IP available; cannot configure Storage Account $accountName."
      }
      elseif ($false -eq $resourceExists) {
          Write-Output "WARNING: Storage Account $accountName does not exist yet.."
      }
      Write-Output ""

      Write-Output "##### Blob Access #####"
      if ($false -eq $ecpIdentity) {
          Write-Output "INFO: No ECP Identity provided; checking role assignment."
          $assignments = az role assignment list `
              --subscription $subscriptionId `
              --assignee-object-id $objectId `
              --scope $sa.id `
              -o JSON | ConvertFrom-Json | Where-Object {$_.description -eq "ECP_BOOTSTRAP_HELPER"}

          foreach ($assignment in $assignments) {
              Write-Host "    Removing $objectId access with role '$assignment.roleDefinitionId' on $accountName"
              az role assignment delete `
                  --subscription $subscriptionId ` `
                  --ids $assignment.id | Out-Null
          }
          if ($assignments.Count -eq 0) {
              Write-Output "INFO:    No RBAC role assignments with description 'ECP_BOOTSTRAP_HELPER' found for $objectId on $accountName."
          }
      }
  }
  else {
      Write-Output "INFO: Storage Account does not exist yet; cannot configure access."
  }
  Write-Output ""
  SCRIPT
      ]
      # run regardless of whether the terraform command failed
      run_on_error = true
    }
}

inputs = {
  launchpad_ado_managed_pool = dependency.l0-lp-ado-mpool.outputs.managed_devops_pool
}
