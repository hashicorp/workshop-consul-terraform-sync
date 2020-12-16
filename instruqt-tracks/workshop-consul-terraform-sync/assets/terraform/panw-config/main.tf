terraform {
  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "1.6.3"
    }
  }
}

data "terraform_remote_state" "panw-vm" {
  backend = "local"

  config = {
    path = "../panw-vm/terraform.tfstate"
  }
}


provider "panos" {
  hostname = data.terraform_remote_state.panw-vm.outputs.FirewallIP
  username = var.adminUsername
  password = var.adminPassword
}

# Virtual router

resource "panos_virtual_router" "vr1" {
  vsys       = "vsys1"
  name       = "vr1"
  interfaces = [
    panos_ethernet_interface.ethernet1_1.name,
    panos_ethernet_interface.ethernet1_2.name,
    panos_ethernet_interface.ethernet1_3.name
  ]
}


# Internet

resource "panos_ethernet_interface" "ethernet1_1" {
  vsys                      = "vsys1"
  name                      = "ethernet1/1"
  mode                      = "layer3"
  enable_dhcp               = true
  create_dhcp_default_route = true
  comment                   = "Internet interface"
}

resource "panos_zone" "internet_zone" {
  name = "Internet"
  mode = "layer3"
}

resource "panos_zone_entry" "internet_zone_ethernet1_1" {
  zone      = panos_zone.internet_zone.name
  mode      = panos_zone.internet_zone.mode
  interface = panos_ethernet_interface.ethernet1_1.name
}


# DMZ

resource "panos_ethernet_interface" "ethernet1_2" {
  vsys        = "vsys1"
  name        = "ethernet1/2"
  mode        = "layer3"
  enable_dhcp = true
  comment     = "DMZ interface"
}

resource "panos_zone" "dmz_zone" {
  name = "DMZ"
  mode = "layer3"
}

resource "panos_zone_entry" "dmz_zone_ethernet1_2" {
  zone      = panos_zone.dmz_zone.name
  mode      = panos_zone.dmz_zone.mode
  interface = panos_ethernet_interface.ethernet1_2.name
}


# Application

resource "panos_ethernet_interface" "ethernet1_3" {
  vsys        = "vsys1"
  name        = "ethernet1/3"
  mode        = "layer3"
  enable_dhcp = true
  comment     = "Application interface"
}

resource "panos_zone" "app_zone" {
  name = "Application"
  mode = "layer3"
}

resource "panos_zone_entry" "app_zone_ethernet1_3" {
  zone      = panos_zone.app_zone.name
  mode      = panos_zone.app_zone.mode
  interface = panos_ethernet_interface.ethernet1_3.name
}