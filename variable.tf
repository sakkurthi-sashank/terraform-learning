variable "resource_group_name" {
  description = "The name of the resource group"
  default     = "predli-demo-rg"
}

variable "location" {
  description = "The Azure region to deploy resources in"
  default     = "South India"
}

variable "vm_name" {
  description = "The name of the virtual machine"
  default     = "predli-demo-vm"
}

variable "admin_username" {
  description = "The admin username for the VM"
  default     = "azureuser"
}

variable "admin_password" {
  description = "The admin password for the VM"
  default     = "Password123!"
}
