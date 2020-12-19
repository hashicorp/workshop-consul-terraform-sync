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
  username = data.terraform_remote_state.panw-vm.outputs.pa_username
  password = data.terraform_remote_state.panw-vm.outputs.pa_password
}
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
  username = data.terraform_remote_state.panw-vm.outputs.pa_username
  password = data.terraform_remote_state.panw-vm.outputs.pa_password
}


# Virtual router

resource "panos_virtual_router" "vr1" {
  vsys = "vsys1"
  name = "vr1"
  interfaces = [
    panos_ethernet_interface.ethernet1_1.name,
    panos_ethernet_interface.ethernet1_2.name,
    panos_ethernet_interface.ethernet1_3.name
  ]
}

resource "panos_static_route_ipv4" "default_route" {
  name           = "default"
  virtual_router = panos_virtual_router.vr1.name
  destination    = "0.0.0.0/0"
  next_hop       = "10.3.2.1"
  interface      = panos_ethernet_interface.ethernet1_1.name
}


# Management interface profile

resource "panos_management_profile" "allow_ping_mgmt_profile" {
  name = "allow-ping"
  ping = true
}


# Internet

resource "panos_ethernet_interface" "ethernet1_1" {
  vsys               = "vsys1"
  name               = "ethernet1/1"
  mode               = "layer3"
  enable_dhcp        = true
  management_profile = "allow-ping"
  comment            = "Internet interface"
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
  vsys               = "vsys1"
  name               = "ethernet1/2"
  mode               = "layer3"
  enable_dhcp        = true
  management_profile = "allow-ping"
  comment            = "DMZ interface"
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
  vsys               = "vsys1"
  name               = "ethernet1/3"
  mode               = "layer3"
  enable_dhcp        = true
  management_profile = "allow-ping"
  comment            = "Application interface"
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


# NAT Rule

resource "panos_nat_rule_group" "app" {
  rule {
    name = "second"
    original_packet {
      source_zones          = ["Internet"]
      destination_zone      = "Internet"
      source_addresses      = ["any"]
      destination_addresses = ["10.3.2.5"]
    }
    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = panos_ethernet_interface.ethernet1_2.name
          }
        }
      }
      destination {
        static_translation {
          address = "10.3.3.4"
        }
      }
    }
  }
}

# Security Rule

resource "panos_security_rule_group" "allow_app_traffic" {
  position_keyword = "top"
  rule {
    name                  = "Allow traffic to BIG-IP"
    source_zones          = ["Internet"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["DMZ"]
    destination_addresses = ["10.3.2.5"]
    applications          = ["any"]
    services              = ["service-http", "service-https"]
    categories            = ["any"]
    action                = "allow"
    description           = "Allow app traffic from Internet to BIG-IP"
  }
  rule {
    name                  = "Allow traffic from BIG-IP to App"
    source_zones          = ["DMZ"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["Application"]
    destination_addresses = ["10.3.4.111"]
    applications          = ["any"]
    services              = ["service-http", "service-https"]
    categories            = ["any"]
    action                = "allow"
    description           = "Allow app traffic from BIG-IP to app server"
  }
}