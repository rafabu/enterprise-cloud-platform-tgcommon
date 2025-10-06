dependency "l0-lp-az-lp-bootstrap-helper" {
  config_path = format("%s/../az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
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

dependency "l0-lp-az-backend" {
  config_path = format("%s/../az-launchpad-backend", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name = "mock-rg"
      location = "nowhere"
    }
    storage_accounts = {
      l0 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl0"
        name = "mockstl0"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl0.blob.core.windows.net"
          private_ip_address = "192.0.2.4"
        }
        ecp_level = "l0"
        tf_backend_container = "tfstate"
      }
      l1 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl1"
        name = "mockstl1"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl1.blob.core.windows.net"
          private_ip_address = "192.0.2.5"
        }
        ecp_level = "l1"
        tf_backend_container = "tfstate"
      }
      l2 = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockstl2"
        name = "mockstl2"
        location = "nowhere"
        private_endpoint_blob ={
          fqdn = "mockstl2.blob.core.windows.net"
          private_ip_address = "192.0.2.6"
        }
        ecp_level = "l2"
        tf_backend_container = "tfstate"
      }
    }
  }
}

dependency "l0-lp-az-devcenter" {
  config_path = format("%s/../az-devcenter", get_original_terragrunt_dir())
  mock_outputs = {
    dev_center = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/devcenters/mock-devcenter"
      name = "mock-devcenter"
      location = "nowhere"
      resource_group_name = "mock-rg"
    }
    dev_center_project = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/projects/mock-project"
        name = "mock-project "
        location = "nowhere"
        resource_group_name = "mock-rg"
      }
  }
}

dependency "l0-lp-az-ado-project" {
  config_path = format("%s/../ado-project", get_original_terragrunt_dir())
  mock_outputs = {}
}

locals {
  ecp_deployment_unit = "ado-mpool"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-mpool"

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

################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = get_env("TG_DOWNLOAD_DIR", trimspace(run_cmd("pwsh", "-NoLogo", "-NoProfile", "-Command", "[System.IO.Path]::GetTempPath()")))
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type = local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend
  bootstrap_backend_type_changed = local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

################# tags #################
  unit_common_azure_tags = {
     "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
  }
}

# work with local backend if remote backend doesn't exist yet
remote_state {
 backend = local.bootstrap_backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.bootstrap_backend_type == "azurerm" ? {
    subscription_id      = local.bootstrap_helper_output.backend_storage_accounts["l0"].subscription_id
    resource_group_name  = local.bootstrap_helper_output.backend_storage_accounts["l0"].resource_group_name
    storage_account_name = local.bootstrap_helper_output.backend_storage_accounts["l0"].name
    container_name       = local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container
    use_azuread_auth     = true
    key                  = "${basename(path_relative_to_include())}.tfstate"
  } : {
    path = local.bootstrap_local_backend_path
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
}

terraform {

  before_hook "Copy-TerraformStateToRemote" {
     commands     = [
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
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
Write-Output "INFO: bootstrap_backend_type: '${local.bootstrap_backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
  if ("azurerm" -eq "${local.bootstrap_backend_type}") {
    Write-Output "      remote backend changed from 'local' to 'azurerm'; copying local state to remote now..."
    Write-Output "      uploading '${local.bootstrap_local_backend_path}' to '${basename(path_relative_to_include())}.tfstate' on ${local.bootstrap_helper_output.backend_storage_accounts["l0"].name}"  
    az storage blob upload --account-name ${local.bootstrap_helper_output.backend_storage_accounts["l0"].name} --container-name ${local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress | Out-Null
    terraform init -reconfigure | Out-Null
  }
  else {
    Write-Output "      remote backend changed to 'local'; no action required as local state is already in place"
    az storage blob download --account-name ${local.bootstrap_helper_output.backend_storage_accounts["l0"].name} --container-name ${local.bootstrap_helper_output.backend_storage_accounts["l0"].tf_backend_container} --file "${local.bootstrap_local_backend_path}" --name "${basename(path_relative_to_include())}.tfstate" --overwrite --auth-mode "login" --no-progress | Out-Null
    terraform init -reconfigure | Out-Null
  }
}
else {
  Write-Output "INFO: backend has not changed; no action required"
}
SCRIPT
    ]
    run_on_error = false
  }

# # #   after_hook "Close-RemoteBackend-Access" {
# # #      commands     = [
# # #       "apply",
# # #       # "destroy",  # during destroy the remote state should no longer be present
# # #       "force-unlock",
# # #       "import",
# # #       # "init", 
# # #       # "output",
# # #       # "plan", 
# # #       # "refresh",
# # #       # "state",
# # #       # "taint",
# # #       # "untaint",
# # #       # "validate"
# # #       ]
# # #     execute      = [
# # #       "pwsh",
# # #       "-Command", 
# # # <<-SCRIPT
# # # Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"
# # # # if not running from within launchpad network, access to backend will be blocked by storage account firewall
# # # #     always(!) need to remove access again --> run_on_error = true
# # # # remove temporary fw and RBAC again
# # # Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

# # # $resourceExists = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].ecp_resource_exists == true}") { $true } else { $false }
# # # $ipInRange = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.is_local_ip_within_ecp_launchpad == true}") { $true } else { $false }
# # # $publicIp = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_network_information.public_ip}"
# # # $subscriptionId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].subscription_id}"
# # # $accountName = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.backend_storage_accounts["l0"].name}"

# # # $objectId = "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.object_id}"
# # # $ecpIdentity = if ("true" -eq "${dependency.l0-lp-az-lp-bootstrap-helper.outputs.actor_identity.is_ecp_launchpad_identity == true}") { $true } else { $false }

# # # if ($true -eq $resourceExists) {
# # #     Write-Output "INFO: Storage Account should exist; querying"
# # #     $sa = az storage account show `
# # #         --subscription $subscriptionId `
# # #         --name $accountName `
# # #         -o json | ConvertFrom-Json
# # #     Write-Output ""

# # #     Write-Output "##### network access #####"
# # #     if ($true -eq $resourceExists -and $false -eq $ipInRange -and $publicIp -ne $null) {
# # #         Write-Output "INFO: Checking Storage Account $accountName for public IP $publicIp access..."
# # #         # Get current allowed IPs
# # #         $rules = az storage account network-rule list `
# # #             --subscription $subscriptionId `
# # #             --account-name $accountName `
# # #             --query "ipRules[].ipAddressOrRange" `
# # #             -o tsv
# # #         if ($rules -contains $publicIp) {
# # #              Write-Output "     Remove $publicIp from network-rule of storage account $accountName..."
# # #             az storage account network-rule remove `
# # #                 --subscription $subscriptionId `
# # #                 --account-name $accountName `
# # #                 --ip-address $publicIp | Out-Null
# # #             Write-Output "     removed..."
# # #         }
# # #         else {
# # #             Write-Output "    $publicIp not in network-rule of storage account $accountName."
# # #         }
# # #          if ($sa.publicNetworkAccess -eq "Enabled") {
# # #             Write-Output "     Disable public network access again..."
# # #             az storage account update `
# # #                 --subscription $subscriptionId `
# # #                 --name $accountName `
# # #                 --public-network-access Disabled | Out-Null
# # #         }
# # #         else {
# # #             Write-Output "     Public network access already disabled."
# # #         }
# # #     }
# # #     elseif ($true -eq $ipInRange) {
# # #         Write-Output "INFO: Private IP is in launchpad vnet range"
# # #     }
# # #     elseif ($publicIp -eq $null) {
# # #         Write-Output "WARNING: No public IP available; cannot configure Storage Account $accountName."
# # #     }
# # #     elseif ($false -eq $resourceExists) {
# # #         Write-Output "WARNING: Storage Account $accountName does not exist yet.."
# # #     }
# # #     Write-Output ""

# # #     Write-Output "##### Blob Access #####"
# # #     if ($false -eq $ecpIdentity) {
# # #         Write-Output "INFO: No ECP Identity provided; checking role assignment."
# # #         $assignments = az role assignment list `
# # #             --subscription $subscriptionId `
# # #             --assignee-object-id $objectId `
# # #             --scope $sa.id `
# # #             -o JSON | ConvertFrom-Json | Where-Object {$_.description -eq "ECP_BOOTSTRAP_HELPER"}

# # #         foreach ($assignment in $assignments) {
# # #             Write-Host "    Removing $objectId access with role '$assignment.roleDefinitionId' on $accountName"
# # #             az role assignment delete `
# # #                 --subscription $subscriptionId ` `
# # #                 --ids $assignment.id | Out-Null
# # #         }
# # #     }
# # # }
# # # else {
# # #     Write-Output "INFO: Storage Account does not exist yet; cannot configure access."
# # # }
# # # Write-Output ""
# # # SCRIPT
# # #     ]
# # #     # run regardless of whether the terraform command failed
# # #     run_on_error = true
# # #   }
}

inputs = {
  azure_tags = local.unit_common_azure_tags
   
  virtual_network_id = dependency.l0-lp-az-net.outputs.virtual_networks.l0-launchpad-main.id
  
  # load merged vnet artefact objects
  virtual_network_subnet_definitions = local.virtualNetworkSubnet_definition_merged

  # define which artefacts from the libraries we need to create
  subnet_artefact_names = [
    "l0-launchpad-ado-mpool-platform"
  ]

  backend_storage_accounts = dependency.l0-lp-az-backend.outputs.storage_accounts

  workload_identity_type = "userAssignedIdentity" # "serviceprincipal"

  dev_center_project_resource_id = dependency.l0-lp-az-devcenter.outputs.dev_center_project.id
}
