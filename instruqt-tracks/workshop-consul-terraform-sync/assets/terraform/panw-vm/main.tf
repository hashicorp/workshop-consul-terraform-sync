/*
Using the AzCLI, accept the offer terms prior to deployment. This only
need to be done once per subscription
```
az vm image terms accept --urn paloaltonetworks:vmseries1:bundle1:latest
```
*/

provider "azurerm" {
  version = "=2.13.0"
  features {}
}

data "terraform_remote_state" "vnet" {
  backend = "local"

  config = {
    path = "../vnet/terraform.tfstate"
  }
}

resource random_integer "password-length" {
  min = 12
  max = 25
}

resource "random_password" "pafwpassword" {
  length           = random_integer.password-length.result
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  special          = true
  override_special = "_%@"
}

resource "azurerm_storage_account" "PAN_FW_STG_AC" {
  name                     = var.StorageAccountName
  location                 = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name      = data.terraform_remote_state.vnet.outputs.resource_group_name
  account_replication_type = "LRS"
  account_tier             = "Standard" 
}

resource "azurerm_public_ip" "PublicIP_0" {
  name                = var.fwpublicIPName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = var.FirewallDnsName
}

resource "azurerm_public_ip" "PublicIP_1" {
  name                = var.WebPublicIPName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = var.WebServerDnsName
}

resource "azurerm_network_interface" "VNIC0" {
  name                = join("", list("FW", var.nicName, "0"))
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  depends_on          = [azurerm_public_ip.PublicIP_0]

  ip_configuration {
    name                          = join("", list("ipconfig", "0"))
    subnet_id                     = data.terraform_remote_state.vnet.outputs.mgmt_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressMgmtNetwork
    public_ip_address_id          = azurerm_public_ip.PublicIP_0.id
  }

  tags = {
    displayName = join("", list("NetworkInterfaces", "0"))
  }
}

resource "azurerm_network_interface" "VNIC1" {
  name                 = join("", list("FW", var.nicName, "1"))
  location             = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name  = data.terraform_remote_state.vnet.outputs.resource_group_name
#  depends_on           = [azurerm_virtual_network.dmz_subnet]
  enable_ip_forwarding = true

  ip_configuration {
    name                          = join("", list("ipconfig", "1"))
    subnet_id                     = data.terraform_remote_state.vnet.outputs.internet_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressInternetNetwork
    public_ip_address_id          = azurerm_public_ip.PublicIP_1.id
  }

  tags =  {
    displayName = join("", list("NetworkInterfaces", "1"))
  }
}

resource "azurerm_network_interface" "VNIC2" {
  name                 = join("", list("FW", var.nicName, "2"))
  location             = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name  = data.terraform_remote_state.vnet.outputs.resource_group_name
#  depends_on           = [azurerm_virtual_network.dmz_subnet]
  enable_ip_forwarding = true

  ip_configuration {
    name                          = join("", list("ipconfig", "2"))
    subnet_id                     = data.terraform_remote_state.vnet.outputs.dmz_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressDmzNetwork
  }

  tags =  {
    displayName = join("", list("NetworkInterfaces", "2"))
  }
}

resource "azurerm_network_interface" "VNIC3" {
  name                 = join("", list("FW", var.nicName, "3"))
  location             = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name  = data.terraform_remote_state.vnet.outputs.resource_group_name
#  depends_on           = [azurerm_virtual_network.dmz_subnet]
  enable_ip_forwarding = true

  ip_configuration {
    name                          = join("", list("ipconfig", "3"))
    subnet_id                     = data.terraform_remote_state.vnet.outputs.app_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressAppNetwork
  }

  tags =  {
    displayName = join("", list("NetworkInterfaces", "3"))
  }
}

resource "azurerm_virtual_machine" "PAN_FW_FW" {
  name                = var.FirewallVmName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  vm_size             = var.FirewallVmSize

  depends_on = [azurerm_network_interface.VNIC0,
                azurerm_network_interface.VNIC1,
                azurerm_network_interface.VNIC2,
                azurerm_network_interface.VNIC3,
                azurerm_public_ip.PublicIP_0,
                azurerm_public_ip.PublicIP_1
                ]
  plan {
    name      = var.fwSku
    publisher = var.fwPublisher
    product   = var.fwOffer
  }

  storage_image_reference {
    publisher = var.fwPublisher
    offer     = var.fwOffer
    sku       = var.fwSku
    version   = "latest"
  }

  storage_os_disk {
    name          = join("", list(var.FirewallVmName, "-osDisk"))
    vhd_uri       = "${azurerm_storage_account.PAN_FW_STG_AC.primary_blob_endpoint}vhds/${var.FirewallVmName}-${var.fwOffer}-${var.fwSku}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = var.FirewallVmName
    admin_username = var.adminUsername
    admin_password = random_password.pafwpassword.result
  }

  primary_network_interface_id = azurerm_network_interface.VNIC0.id
  network_interface_ids = [azurerm_network_interface.VNIC0.id,
                           azurerm_network_interface.VNIC1.id,
                           azurerm_network_interface.VNIC2.id,
                           azurerm_network_interface.VNIC3.id
                           ]

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
