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
  value       = "http://${coalesce(azurerm_public_ip.peerlearn.fqdn, azurerm_public_ip.peerlearn.ip_address)}"
}

output "jenkins_url" {
  description = "Jenkins URL (accessible only from allowed_jenkins_cidr)."
  value       = "http://${azurerm_public_ip.peerlearn.ip_address}:8080"
}

output "resource_group_name" {
  description = "Azure resource group containing PeerLearn."
  value       = azurerm_resource_group.peerlearn.name
}
