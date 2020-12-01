output "resource_group_name" {
  value = azurerm_resource_group.instruqt.name
}

output "resource_group_location" {
  value = azurerm_resource_group.instruqt.location
}

output "shared_svcs_vnet" {
  value = module.shared-svcs-network.vnet_id
}

output "shared_svcs_subnets" {
  value = module.shared-svcs-network.vnet_subnets
}

output "app_vnet" {
  value = module.app-network.vnet_id
}

output "app_subnet" {
  value = module.app-network.vnet_subnets[1]
}

output "dmz_subnet" {
  value = module.app-network.vnet_subnets[0]
}

output "bastion_ip" {
  value = azurerm_public_ip.bastion.ip_address
}
