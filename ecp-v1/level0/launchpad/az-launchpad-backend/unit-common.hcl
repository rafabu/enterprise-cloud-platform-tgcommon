dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
}

dependency "l0-lp-az-lp-main" {
  config_path = format("%s/../az-launchpad-main", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
  }
}

dependency "l0-lp-az-lp-net" {
  config_path = format("%s/../az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
    virtual_networks = {
      l0-launchpad-main = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
        name = "mock-vnet"
        resource_group_name = "mock-rg"
        location = "nowhere"
        address_space = [
          "192.0.2.0/24"
        ]
      }
    }
    virtual_network_subnets = {
      l0-launchpad-main-default = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name = "mock"
        resource_group_name = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
  }
}

locals {
  ecp_deployment_unit = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-backend"

################# tags #################
  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

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
# assure storage account RBAC and firewall access
  before_hook "Set-RemoteBackend-Access" {
    commands     = ["init", "plan", "apply"]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     temporarily(!) open up access for the duration of this run
#     plus RBAC permissions if not using ECP Identity

$resourceExists = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}") { $true } else { $false }
$ipInRange = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad == true}") { $true } else { $false }
$publicIp = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}"
$subscriptionId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].subscription_id}"
$accountName = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].name}"

$objectId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.object_id}"
$ecpIdentity = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.is_ecp_launchpad_identity == true}") { $true } else { $false }
$principalType = if ("user" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.type}") { "User" } else { "ServicePrincipal" }
$roleName = if ($env:TG_CTX_COMMAND -eq "apply") { "Storage Blob Data Contributor" } else { "Storage Blob Data Reader" }

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
    Write-Output "INFO: Waiting 20 seconds for changes to propagate..."
    Start-Sleep -Seconds 20
}
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
   
  virtual_subnet_id = dependency.l0-lp-az-lp-net.outputs.virtual_network_subnets.l0-launchpad-main-default.id

  # if running from outside ECP network, storage account must allow (temporary)public network access
  storage_account_public_network_access_enabled = dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad == true ? false : true
}
