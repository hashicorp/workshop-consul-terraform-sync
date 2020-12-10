
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