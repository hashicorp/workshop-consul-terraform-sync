output "FirewallIP" {
  value = join("", list("https://", azurerm_public_ip.PublicIP_0.ip_address))
}

output "FirewallFQDN" {
  value = join("", list("https://", azurerm_public_ip.PublicIP_0.fqdn))
}

output "WebIP" {
  value = join("", list("http://", azurerm_public_ip.PublicIP_1.ip_address))
}

output "WebFQDN" {
  value = join("", list("http://", azurerm_public_ip.PublicIP_1.fqdn))
}