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

resource "azurerm_storage_account" "PAN_FW_STG_AC" {
  name                     = var.StorageAccountName
  location                 = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name      = data.terraform_remote_state.vnet.outputs.resource_group_name
  account_replication_type = "LRS"
  account_tier             = "Standard" 
}

## START Firewall VM-Series Bootstrap ##
resource "azurerm_storage_share" "bootstrap-storage-share" {
  name                 = "bootstrapshare-${var.StorageAccountName}"
  storage_account_name = azurerm_storage_account.PAN_FW_STG_AC.name
}

data "template_file" "render-init-cfg" {
  template = file("${path.module}/init-cfg.tmpl")
  vars = {
    "hostname"         = var.hostname,
    "tplname"          = var.tplname,
    "dgname"           = var.dgname,
    "dns-primary"      = var.dns-primary,
    "dns-secondary"    = var.dns-secondary,
    "vm-auth-key"      = var.vm-auth-key,
    "op-command-modes" = var.op-command-modes
  }
}

resource "local_file" "write-init-cfg" {
  content  = data.template_file.render-init-cfg.rendered
  filename = "${path.root}/files/config/init-cfg.txt"
}

resource "null_resource" "file_uploads" {

  provisioner "local-exec" {
    command = "az storage directory create --name config --share-name ${azurerm_storage_share.bootstrap-storage-share.name} --account-name ${azurerm_storage_account.PAN_FW_STG_AC.name} --account-key ${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key}"
  }

  provisioner "local-exec" {
    command = "az storage directory create --name content --share-name ${azurerm_storage_share.bootstrap-storage-share.name} --account-name ${azurerm_storage_account.PAN_FW_STG_AC.name} --account-key ${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key}"
  }

  provisioner "local-exec" {
    command = "az storage directory create --name license --share-name ${azurerm_storage_share.bootstrap-storage-share.name} --account-name ${azurerm_storage_account.PAN_FW_STG_AC.name} --account-key ${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key}"
  }

  provisioner "local-exec" {
    command = "az storage directory create --name software --share-name ${azurerm_storage_share.bootstrap-storage-share.name} --account-name ${azurerm_storage_account.PAN_FW_STG_AC.name} --account-key ${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key}"
  }

  provisioner "local-exec" {
    command = "cd ${path.root}/files; az storage file upload-batch --account-name ${azurerm_storage_account.PAN_FW_STG_AC.name} --account-key ${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key} --source . --destination ${azurerm_storage_share.bootstrap-storage-share.name}"
  }

}
## END Firewall VM-Series Bootstrap ##

## START Firewall VM-Series ##
resource "azurerm_public_ip" "PublicIP_0" {
  name                = var.fwpublicIPName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  allocation_method   = var.publicIPAddressType
  domain_name_label   = var.FirewallDnsName
}

resource "azurerm_public_ip" "PublicIP_1" {
  name                = var.WebPublicIPName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  allocation_method   = var.publicIPAddressType
  domain_name_label   = var.WebServerDnsName
}

resource "azurerm_network_interface" "VNIC0" {
  name                = join("", list("FW", var.nicName, "0"))
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  depends_on          = [azurerm_public_ip.PublicIP_0]

  ip_configuration {
    name                          = join("", list("ipconfig", "0"))
    subnet_id                     = data.terraform_remote_state.vnet.outputs.dmz_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressDmzNetwork
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
    subnet_id                     = data.terraform_remote_state.vnet.outputs.app_subnet
    private_ip_address_allocation = "static"
    private_ip_address            = var.IPAddressAppNetwork
    public_ip_address_id          = azurerm_public_ip.PublicIP_1.id
  }

  tags =  {
    displayName = join("", list("NetworkInterfaces", "1"))
  }
}

resource "azurerm_virtual_machine" "PAN_FW_FW" {
  name                = var.FirewallVmName
  location            = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.vnet.outputs.resource_group_name
  vm_size             = var.FirewallVmSize

  depends_on = [azurerm_network_interface.VNIC0,
                azurerm_network_interface.VNIC1,
                null_resource.file_uploads
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
    admin_password = var.adminPassword
    custom_data = join(
      ",",
      [
        "storage-account=${azurerm_storage_account.PAN_FW_STG_AC.name}",
        "access-key=${azurerm_storage_account.PAN_FW_STG_AC.primary_access_key}",
#        "file-share=${azurerm_storage_share.bootstrap-storage-share.name}"
        "file-share=${azurerm_storage_share.bootstrap-storage-share.url}"
      ],
    )
  }

  primary_network_interface_id = azurerm_network_interface.VNIC0.id
  network_interface_ids = [azurerm_network_interface.VNIC0.id,
                           azurerm_network_interface.VNIC1.id
#                           azurerm_network_interface.VNIC2.id
                           ]

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

## END Firewall VM-Series ##
