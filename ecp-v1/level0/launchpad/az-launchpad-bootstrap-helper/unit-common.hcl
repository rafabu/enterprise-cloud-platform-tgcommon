locals {
  ecp_deployment_unit = "tfbcknd"
  ecp_resource_name_random_length = 0

  azure_tf_module_folder = "launchpad-bootstrap-helper"
}

# helper module does not need a backend; can and should run with local state (as it is stateless anyway)
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = null
}

inputs = {
}
