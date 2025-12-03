dependencies {
  paths = [
    format("%s/../../bootstrap/az-launchpad-bootstrap-helper", get_original_terragrunt_dir())
  ]
}

dependency "l0-lp-az-net" {
  config_path = format("%s/../az-launchpad-network", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    virtual_networks = {
      l0-launchpad-main = {
        id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
        name                = "mock-vnet"
        resource_group_name = "mock-rg"
        location            = "westeurope"
        address_space = [
          "192.0.2.0/24"
        ]
      }
    }
    virtual_network_subnets = {
      l0-launchpad-main-default = {
        id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
        name                 = "mock"
        resource_group_name  = "mock-rg"
        virtual_network_name = "mock-vnet"
        address_prefixes = [
          "192.0.2.0/24"
        ]
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l0-lp-az-backend" {
  config_path = format("%s/../az-launchpad-backend", get_original_terragrunt_dir())
  mock_outputs = {
    resource_group = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
      name     = "mock-rg"
      location = "westeurope"
    }
    storage_accounts = {
      l0 = {
        ecp_level = "l0"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal0"
        name      = "mocksal0"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal0.blob.core.windows.net"
          private_ip_address = "192.0.2.4"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
      l1 = {
        ecp_level = "l1"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal1"
        name      = "mocksal1"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal1.blob.core.windows.net"
          private_ip_address = "192.0.2.5"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
      l2 = {
        ecp_level = "l2"
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mocksal2"
        name      = "mocksal2"
        location  = "westeurope"
        private_endpoint_blob = {
          fqdn               = "mocksal2.blob.core.windows.net"
          private_ip_address = "192.0.2.6"
          subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock"
          subresource_names = [
            "blob",
          ]
        }
        tf_backend_container = "tfstate"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l0-lp-az-devcenter" {
  config_path = format("%s/../az-devcenter", get_original_terragrunt_dir())
  mock_outputs = {
    dev_center = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/devcenters/mock-devcenter"
      name                = "mock-devcenter"
      location            = "westeurope"
      resource_group_name = "mock-rg"
    }
    dev_center_project = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.DevCenter/projects/mock-project"
      name                = "mock-project "
      location            = "westeurope"
      resource_group_name = "mock-rg"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "l0-lp-az-ado-project" {
  config_path                             = format("%s/../ado-project", get_original_terragrunt_dir())
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  ecp_deployment_unit             = "ado-mpool"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "ado-mpool"

  library_path_shared = format("%s/lib/ecp-lib", get_repo_root())
  library_path_unit   = "${get_terragrunt_dir()}/lib"

  ################# virtual network subnet artefacts #################
  # exclude the ones named in the *.exclude.json
  library_virtualNetworkSubnets_path_shared    = "${local.library_path_shared}/platform/ecp-artefacts/ms-azure/network/virtualNetworkSubnets"
  library_virtualNetworkSubnets_path_unit      = "${local.library_path_unit}/virtualNetworkSubnets"
  library_virtualNetworkSubnets_filter         = "*.virtualNetworkSubnet.json"
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
      if(contains(keys(local.virtualNetworkSubnet_definition_exclude_unit), key) == false)
    },
    local.virtualNetworkSubnet_definition_unit
  )

  ################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = coalesce(
    try(get_env("TG_DOWNLOAD_DIR"), null),
    try(get_env("TMPDIR"), null),
    try(trimspace(run_cmd("--terragrunt-quiet", "pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[System.IO.Path]::GetTempPath()")), null),
    "/tmp"
  )
  bootstrap_helper_folder        = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output        = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type         = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true ? "azurerm" : "local", "local")
  bootstrap_backend_type_changed = try(local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_terraform_backend_changed_since_last_apply, false)
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"
  # do we need to deploy a NAT gateway?
  launchpad_network_island_mode = try(local.bootstrap_helper_output.actor_network_information.ecp_launchpad_network_island_mode, false)

  ################# tags #################
  unit_common_azure_tags = {
    # "_ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
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
      # "destroy",  # child of az-launchpad-backend: no need to migrate back to local state during destroy
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
Write-Output "INFO: bootstrap_backend_type: '${local.bootstrap_backend_type}'"
Write-Output "INFO: bootstrap_backend_type_changed: '${local.bootstrap_backend_type_changed}'"

if ("true" -eq "${local.bootstrap_backend_type_changed}") {
    if ("azurerm" -eq "${local.bootstrap_backend_type}") {
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
}

inputs = {
  azure_tags = local.unit_common_azure_tags

  virtual_network_id = dependency.l0-lp-az-net.outputs.virtual_networks.l0-launchpad-main.id

  # load merged vnet artefact objects
  virtual_network_subnet_definitions = local.virtualNetworkSubnet_definition_merged

  # virtual network is not yet connected to infrastructure that will route traffic to internet (we need a NAT gateway)
  virtual_network_island_mode = local.launchpad_network_island_mode

  # define which artefacts from the libraries we need to create
  subnet_artefact_names = [
    "l0-launchpad-ado-mpool-platform"
  ]

  backend_storage_accounts = dependency.l0-lp-az-backend.outputs.storage_accounts

  workload_identity_type = "userAssignedIdentity" # "serviceprincipal"

  dev_center_project_resource_id = dependency.l0-lp-az-devcenter.outputs.dev_center_project.id

  managed_devops_pool_maximum_concurrency = 2
  managed_devops_pool_stateless_agent_profile = {
    manual_resource_predictions_profile = {
      time_zone = "W. Europe Standard Time"
      # all_week_schedule = 2
      monday_schedule = {
        "07:30:00" = 2,
        "21:00:00" = 0
      }
      tuesday_schedule = {
        "07:30:00" = 2,
        "21:00:00" = 0
      }
      wednesday_schedule = {
        "07:30:00" = 2,
        "21:00:00" = 0
      }
      thursday_schedule = {
        "07:30:00" = 2,
        "21:00:00" = 0
      }
      friday_schedule = {
        "07:30:00" = 2,
        "21:00:00" = 0
      }
      saturday_schedule = {}
      sunday_schedule   = {}
    }
  }
  managed_devops_pool_vmss_fabric_profile = {
    sku_name = "Standard_D2as_v5"
    image = [
      {
        aliases               = ["ubuntu-24.04/latest"]
        buffer                = "*"
        well_known_image_name = "ubuntu-24.04/latest"
      }
    ]
    os_profile = {
      logon_type = "Service"
    }
    storage_profile = {
      os_disk_storage_account_type = "StandardSSD"
      data_disk                    = []
    }
  }
}
