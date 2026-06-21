variable "tenancy_ocid" {
  type = string
}

variable "availability_domain_name" {
  type = string
}

variable "config_file_profile" {
  type = string
}

variable "free_tier_instances" {
  type = map(object({
    display_name       = string
    shape              = string
    source_image_id    = string
    ssh_authorized_key = string
    tcp_ports          = list(number)
    udp_ports          = list(number)
  }))
}
