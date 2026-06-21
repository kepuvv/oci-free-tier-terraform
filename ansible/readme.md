## Ansible examples

Here there are few examples for a playbook you can use.

`ansible-playbook test_playbook.yml` will run ansible against all VMs.

`ansible oci_vms -m ansible.builtin.setup | grep ansible_distribution`
