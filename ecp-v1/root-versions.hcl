############ Versions ############
locals {
  ecp_configuration_repo_version = "feature/azurerm_5.x" # "main"
  ecp_azure_modules_repo_version = "dev"                 # "v0.5.0-alpha" # "v0.4.1-alpha" # main / dev

  tg_version_automation = "1.1.1"  # pin terragrunt version for pipelines (interactive execution will use the installed version)
  tf_version_automation = "1.15.9" # pin terraform version for pipelines (interactive execution will use the installed version)

  tf_required_version = ">= 1.15" # for versions.tf file generated

  tf_provider_azuread_version     = "~> 3.9"
  tf_provider_azurecaf_version    = "~> 1.2"
  tf_provider_azurerm_version_4   = "~> 4.81"
  tf_provider_azurerm_version_5   = "~> 5.3"
  tf_provider_azapi_version       = "~> 2.12"
  tf_provider_azuredevops_version = "~> 1.16"
  tf_provider_external_version    = "~> 2.4"
  tf_provider_http_version        = "~> 3.6"
  tf_provider_local_version       = "~> 2.9"
  tf_provider_random_version      = "~> 3.9"
  tf_provider_msgraph_version     = "~> 0.4"
  tf_provider_time_version        = "~> 0.14"
  # ALZ
  tf_provider_alz_version = "~> 0.21"

  # refresh to newer ALZ / SLZ / AMBA
  #     IMPORTANT !!!!!
  #     --> also update "alz_library_metadata.json" to reference the same version of ALZ / SLZ
  tf_provider_alz_alz_lib_version  = "2026.04.2"
  tf_provider_alz_slz_lib_version  = "2026.04.3"
  tf_provider_alz_amba_lib_version = "2026.01.1"

  # Azure Verified Modules
  tf_provider_modtm_version = "~> 0.4"

  tf_module_avm-ptn-alz_version                                    = "0.21.0"
  tf_module_avm-ptn-alz-connectivity-virtual-wan_version           = "0.17.1"
  tf_module_avm-ptn-alz-connectivity-hub-and-spoke-vnet_version    = "0.17.4"
  tf_module_avm-ptn-alz-management_version                         = "0.9.0"
  tf_module_avm-ptn-network-private-link-private-dns-zones_version = "0.23.2"
  tf_module_avm-ptn-alz-sub-vending_version                        = "0.3.1"
  tf_module_avm-res-network-natgateway_version                     = "0.3.2"
  # tf_module_avm-res-network-virtualnetwork_version               = "0.19.0"
  # tf_module_avm-res-network-publicipaddress_version                = "0.2.1"
  tf_module_avm-res-storage-storageaccount_version = "0.9.0"
  tf_module_avm-utl-regions_version                = "0.12.0"
}
