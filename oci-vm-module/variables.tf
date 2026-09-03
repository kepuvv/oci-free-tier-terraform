variable "availability_domain_name" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "instances" {
  type = map(object({
    display_name                   = string
    shape                          = string
    source_image_id                = string
    ssh_authorized_key             = string
    tcp_ports                      = list(number)
    udp_ports                      = list(number)
    additional_volume_size_in_gbs  = optional(number, 0)
    additional_volume_backup_count = optional(number, 0)
  }))
}
