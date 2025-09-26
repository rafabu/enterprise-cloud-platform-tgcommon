dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
}

dependency "l0-lp-az-main" {
  config_path = format("%s/../az-launchpad-main", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
  }
}

dependency "l0-lp-az-net" {
  config_path = format("%s/../az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
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
  # root_common_vars = read_terragrunt_config(format("%s/lib/terragrunt-common/ecp-v1/root-common.hcl", get_repo_root()))
  
  ecp_deployment_unit = "main"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "devcenter"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit = "${get_terragrunt_dir()}/lib"

  ################# virtual network subnet artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworkSubnets_path_shared = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworkSubnets"
  library_virtualNetworkSubnets_path_unit= "${local.library_path_unit}/virtualNetworkSubnets"
  library_virtualNetworkSubnets_filter = "*.virtualNetworkSubnet.json"
  library_virtualNetworkSubnets_exclude_filter = "*.virtualNetworkSubnet.exclude.json"

  # load JSON artefact files and bring them into hcl map of objects as input to the terraform module
  virtualNetworkSubnet_definition_shared = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_shared, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_shared, fileName)))
  }, {})
  virtualNetworkSubnet_definition_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
  }, {})
  virtualNetworkSubnet_definition_exclude_unit = try({
    for fileName in fileset(local.library_virtualNetworkSubnets_path_unit, local.library_virtualNetworkSubnets_exclude_filter) : jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName))).artefactName => jsondecode(file(format("%s/%s", local.library_virtualNetworkSubnets_path_unit, fileName)))
  }, {})
  virtualNetworkSubnet_definition_merged = merge(
    {
      for key, val in local.virtualNetworkSubnet_definition_shared : key => val
      if (contains(keys(local.virtualNetworkSubnet_definition_exclude_unit), key) == false)
    },
    local.virtualNetworkSubnet_definition_unit
  )

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
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
    commands     = [
      "apply",
      # "destroy",  # during destroy the remote state should no longer be present
      "force-unlock",
      "import",
      "init", 
      "output",
      "plan", 
      "refresh",
      "state",
      "taint",
      "untaint",
      # "validate"
      ]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
# if not running from within launchpad network, access to backend will be blocked by storage account firewall
#     temporarily(!) open up access for the duration of this run
#     plus RBAC permissions if not using ECP Identity
$tgWriteCommands = @(
  "apply",
  "destroy",
  "force-unlock",
  "import",
  "refresh",
  "taint",
  "untaint"
)

$resourceExists = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}") { $true } else { $false }
$ipInRange = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad == true}") { $true } else { $false }
$publicIp = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}"
$subscriptionId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].subscription_id}"
$accountName = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].name}"

$objectId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.object_id}"
$ecpIdentity = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.is_ecp_launchpad_identity == true}") { $true } else { $false }
$principalType = if ("user" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.type}") { "User" } else { "ServicePrincipal" }
$roleName = if ($tgWriteCommands -contains $env:TG_CTX_COMMAND) { "Storage Blob Data Contributor" } else { "Storage Blob Data Reader" }

# units shouldn't run in parallel, but just in case, wait a random time before checking/setting access
Start-Sleep -Seconds (0..15 | Get-Random)

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
    Write-Output "INFO: Waiting 60 seconds for changes to propagate (RBAC & network rule)..."
    Start-Sleep -Seconds 60
}
SCRIPT
    ]
    run_on_error = false
  }
}

inputs = {
  azure_tags = local.unit_common_azure_tags

  resource_group_id = dependency.l0-lp-az-main.outputs.resource_group.id

  virtual_network_id = dependency.l0-lp-az-net.outputs.virtual_networks.l0-launchpad-main.id
  
  # load merged vnet artefact objects
  virtual_network_subnet_definitions = local.virtualNetworkSubnet_definition_merged

  # define which artefacts from the libraries we need to create
  subnet_artefact_names = [
    "l0-launchpad-devcenter-devbox"
  ]
}
