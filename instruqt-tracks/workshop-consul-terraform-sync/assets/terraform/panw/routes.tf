resource "azurerm_route_table" "PAN_FW_RT_Trust" {
  name                = var.routeTableTrust
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name

  route {
    name           = "Trust-to-intranetwork"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = join("", list(var.IPAddressPrefix, ".2.4"))
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_route_table" "PAN_FW_RT_Web" {
  name                = var.routeTableWeb
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name

  route {
    name           = "Web-to-Firewall-DB"
    address_prefix = join("", list(var.IPAddressPrefix, ".4.0/24"))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = join("", list(var.IPAddressPrefix, ".2.4"))
  }

  route {
    name           = "Web-default-route"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = join("", list(var.IPAddressPrefix, ".2.4"))
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_route_table" "PAN_FW_RT_DB" {
  name                = var.routeTableDB
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name

  route {
    name           = "DB-to-Firewall-Web"
    address_prefix = join("", list(var.IPAddressPrefix, ".3.0/24"))
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = join("", list(var.IPAddressPrefix, ".2.4"))
  }

  route {
    name                   = "DB-default-route"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = join("", list(var.IPAddressPrefix, ".2.4"))
  }

  tags =  {
    environment = "Production"
  }
}

#resource "azurerm_subnet_route_table_association" "example2" {
#  subnet_id                 = azurerm_subnet.app_subnet.id
#  route_table_id            = azurerm_route_table.PAN_FW_RT_Trust.id
#}