/*
Output Variables
*/
output "proxy_ip_addresses" {
  value = "${vsphere_virtual_machine.VBR-PROXY.*.default_ip_address}"
}
output "proxy_vm_names" {
  value = "${vsphere_virtual_machine.VBR-PROXY.*.name}"
}
