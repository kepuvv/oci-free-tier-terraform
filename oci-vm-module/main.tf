terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

locals {
  additional_volume_settings = {
    for k, v in var.instances : k => {
      size_in_gbs  = v.additional_volume_size_in_gbs
      backup_count = v.additional_volume_backup_count
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

  # TODO add tags for instance

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

# The OCI boot volume is always created by default for each instance.
# This optional extra volume is only for additional data storage and its backups.
resource "oci_core_volume" "data_volume" {
  for_each = { for k, v in var.instances : k => v if local.additional_volume_settings[k].size_in_gbs > 0 }

  availability_domain = var.availability_domain_name
  compartment_id      = var.tenancy_ocid
  display_name        = "${each.value.display_name}-data"
  size_in_gbs         = local.additional_volume_settings[each.key].size_in_gbs
}

resource "oci_core_volume_attachment" "data_volume_attachment" {
  for_each = { for k, v in var.instances : k => v if local.additional_volume_settings[k].size_in_gbs > 0 }

  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.instance_vm[each.key].id
  volume_id       = oci_core_volume.data_volume[each.key].id
}

resource "oci_core_volume_backup_policy" "data_volume_backup_policy" {
  for_each = { for k, v in var.instances : k => v if local.additional_volume_settings[k].size_in_gbs > 0 && local.additional_volume_settings[k].backup_count > 0 }

  compartment_id = var.tenancy_ocid
  display_name   = "${each.value.display_name}-backup-policy"

  schedules {
    backup_type       = "FULL"
    period            = "ONE_WEEK"
    retention_seconds = local.additional_volume_settings[each.key].backup_count * 7 * 24 * 60 * 60
    time_zone         = "UTC"
  }
}

resource "oci_core_volume_backup_policy_assignment" "data_volume_backup_policy_assignment" {
  for_each = { for k, v in var.instances : k => v if local.additional_volume_settings[k].size_in_gbs > 0 && local.additional_volume_settings[k].backup_count > 0 }

  asset_id  = oci_core_volume.data_volume[each.key].id
  policy_id = oci_core_volume_backup_policy.data_volume_backup_policy[each.key].id
}