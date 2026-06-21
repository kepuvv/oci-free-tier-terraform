####
## MAIN ROUTING
####
resource "oci_core_vcn" "main_vcn" {
  cidr_blocks = [
    "10.0.0.0/16",
  ]
  compartment_id = var.tenancy_ocid
  display_name   = "main-vcn"
  dns_label      = "mainvcn"
  freeform_tags = {
  }
  ipv6private_cidr_blocks = [
  ]
}

resource "oci_core_internet_gateway" "main_vc_Internet-Gateway" {
  compartment_id = var.tenancy_ocid
  display_name   = "Internet Gateway main-vcn"
  enabled        = "true"
  freeform_tags = {
  }
  vcn_id = oci_core_vcn.main_vcn.id
}

resource "oci_core_subnet" "main_subnet" {
  vcn_id         = oci_core_vcn.main_vcn.id
  compartment_id = var.tenancy_ocid
  cidr_block     = "10.0.0.0/24"
  #dhcp_options_id = oci_core_vcn.main_vcns.default_dhcp_options_id
  display_name = "main-subnet"
  dns_label    = "mainsubnet"
  freeform_tags = {
  }

  prohibit_internet_ingress  = "false"
  prohibit_public_ip_on_vnic = "false"

  # Default security list allows all outbound traffic and inbound SSH on port 22
  security_list_ids = [
    oci_core_vcn.main_vcn.default_security_list_id
  ]
}

resource "oci_core_default_route_table" "Default-Route-Table-for-main-vcn" {
  compartment_id = var.tenancy_ocid
  display_name   = "Default Route Table for main-vcn"
  freeform_tags = {
  }
  manage_default_resource_id = oci_core_vcn.main_vcn.default_route_table_id
  route_rules {
    #description = <<Optional value not found in discovery>>
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main_vc_Internet-Gateway.id
  }
}

## 
## SECURITY GROUPS
## 
resource "oci_core_network_security_group" "instance_nsg" {
  for_each = var.instances

  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "${each.value.display_name}-nsg"
}

## 
## NSG Rules
## 
locals {
  instance_tcp_port_rules = {
    for rule in flatten([
      for instance_key, instance in var.instances : [
        for port in instance.tcp_ports : {
          key          = "${instance_key}-tcp-${port}"
          instance_key = instance_key
          port         = port
        }
      ]
    ]) : rule.key => rule
  }

  instance_udp_port_rules = {
    for rule in flatten([
      for instance_key, instance in var.instances : [
        for port in instance.udp_ports : {
          key          = "${instance_key}-udp-${port}"
          instance_key = instance_key
          port         = port
        }
      ]
    ]) : rule.key => rule
  }
}

resource "oci_core_network_security_group_security_rule" "instance_tcp_ingress" {
  for_each = local.instance_tcp_port_rules

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.instance_nsg[each.value.instance_key].id
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = "false"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "instance_udp_ingress" {
  for_each = local.instance_udp_port_rules

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.instance_nsg[each.value.instance_key].id
  protocol                  = "17"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = "false"

  udp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

####
## SECURITY LISTS
####
resource "oci_core_default_security_list" "default-seclist" {
  compartment_id             = var.tenancy_ocid
  display_name               = "Default Security List for mainvcn"
  manage_default_resource_id = oci_core_vcn.main_vcn.default_security_list_id

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = "false"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = "false"

    tcp_options {
      min = "22"
      max = "22"
    }
  }
}
