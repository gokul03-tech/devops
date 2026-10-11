output "public_ip" {
  description = "Static public IPv4 address for the PeerLearn VM."
  value       = azurerm_public_ip.peerlearn.ip_address
}

output "ssh_command" {
  description = "SSH command for the configured administrator."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.peerlearn.ip_address}"
}

output "app_url" {
  description = "PeerLearn web application URL."
  value       = "http://${azurerm_public_ip.peerlearn.ip_address}"
}

output "resource_group_name" {
  description = "Azure resource group containing PeerLearn."
  value       = azurerm_resource_group.peerlearn.name
}
