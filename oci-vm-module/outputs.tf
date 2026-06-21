output "vm_name" {
  value = {
    for k, vm in oci_core_instance.instance_vm : k => vm.display_name
  }
}

output "vm_ip_address" {
  value = {
    for k, vm in oci_core_instance.instance_vm : k => vm.public_ip
  }
}
