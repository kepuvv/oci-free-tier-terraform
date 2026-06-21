output "vm_list" {
  value = [
    for k, name in module.vm_module.vm_name : {
      hostname   = name
      ip_address = module.vm_module.vm_ip_address[k]
      user       = "ubuntu"
    }
  ]
}

resource "local_file" "ansible_inventory" {
  filename = "ansible/inventory.ini"
  content = format(
    "[oci_vms]\n%s\n",
    join("\n", [
      for k, name in module.vm_module.vm_name :
      "${name} ansible_host=${module.vm_module.vm_ip_address[k]} ansible_user=ubuntu ansible_ssh_private_key_file=${trimsuffix(pathexpand(var.free_tier_instances[k].ssh_authorized_key), ".pub")}"
    ])
  )
}
