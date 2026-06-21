terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

resource "oci_core_instance" "instance_vm" {
  for_each = var.instances

  availability_domain = var.availability_domain_name
  compartment_id      = var.tenancy_ocid
  display_name        = each.value.display_name
  shape               = each.value.shape
  # TODO: Add shape config in case of ARM instance
  # shape_config {
  #   ocpus         = 1
  #   memory_in_gbs = 1
  # }
  source_details {
    source_type = "image"
    source_id   = each.value.source_image_id
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(each.value.ssh_authorized_key))
  }
  preserve_boot_volume = false


  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.main_subnet.id
    # Security group here to allow incoming connections
    nsg_ids = [oci_core_network_security_group.instance_nsg[each.key].id]
  }
}
