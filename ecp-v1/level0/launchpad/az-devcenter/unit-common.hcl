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

dependency "l0-lp-az-lp-backend" {
  config_path = format("%s/../az-launchpad-backend", get_original_terragrunt_dir())
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

################# bootstrap-helper unit output #################
  TG_DOWNLOAD_DIR = get_env("TG_DOWNLOAD_DIR", trimspace(run_cmd("pwsh", "-NoLogo", "-NoProfile", "-Command", "[System.IO.Path]::GetTempPath()")))
  bootstrap_helper_folder = "${local.TG_DOWNLOAD_DIR}/${uuidv5("dns", "az-launchpad-bootstrap-helper")}"
  bootstrap_helper_output = jsondecode(file("${local.bootstrap_helper_folder}/terraform_output.json"))
  bootstrap_backend_type = local.bootstrap_helper_output.backend_storage_accounts["l0"].ecp_resource_exists == true  && get_terraform_command() != "destroy" ? "azurerm" : "local"
  # assure local state resides in bootstrap-helper folder
  bootstrap_local_backend_path = "${local.bootstrap_helper_folder}/${basename(path_relative_to_include())}.tfstate"

################# tags #################
  unit_common_azure_tags = {
     "hidden-ecpTgUnitCommon" = format("%s/unit-common.hcl", get_parent_terragrunt_dir())
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

before_hook "migrate-terraformState" {
    commands     = [
      "apply",
      "destroy",  # during destroy the remote state will be destroyed; so we need to fail back to local state first
      # "force-unlock",
      "import",
      "init", # on initial run, no outputs will be available, yet
      "output",
      "plan", 
      "refresh",
      "state",
      "taint",
      "untaint",
      "validate",
      "destroy"  
      ]
    execute      = [
      "pwsh",
      "-Command", 
<<-SCRIPT
Write-Output "INFO: TG_CTX_COMMAND: $env:TG_CTX_COMMAND"

Write-Output "INFO: check if backend migration to backend '${local.bootstrap_backend_type}' is required"
terraform init -backend=false -input=false | Out-Null
$check = terraform init -reconfigure -input=false -migrate-state=false 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "     backend migration required; performing migration now..."
    terraform init -migrate-state -input=false -force-copy
}
else {
    Write-Output "    backend configuration matches; no migration required."
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
