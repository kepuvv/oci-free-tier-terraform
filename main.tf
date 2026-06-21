terraform {
  # backend "s3" {}

  required_providers {
    oci = {
      source = "oracle/oci"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "oci" {
  config_file_profile = var.config_file_profile
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

module "vm_module" {
  source = "./oci-vm-module"

  availability_domain_name = var.availability_domain_name
  tenancy_ocid             = var.tenancy_ocid
  instances                = var.free_tier_instances
}
