output "primary_blob_endpoint" {
  value = azurerm_storage_account.PAN_FW_STG_AC.primary_blob_endpoint
}

output "storage_account_name" {
  value = azurerm_storage_account.PAN_FW_STG_AC.name
}

output "primary_access_key" {
  value = azurerm_storage_account.PAN_FW_STG_AC.primary_access_key
}

output "bootstrap_share_name" {
  value = azurerm_storage_share.bootstrap-storage-share.name
}
