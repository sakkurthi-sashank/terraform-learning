provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "main" {
  name                = "myPublicIP"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "main" {
  name                = "myNIC"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_B1ms"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_network_security_group" "main" {
  name                = "myNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "null_resource" "wait_for_public_ip" {
  provisioner "local-exec" {
    command = <<EOT
    while [ -z "$(az network public-ip show --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_public_ip.main.name} --query "ipAddress" -o tsv)" ]; do
      echo "Waiting for Public IP to be ready..."
      sleep 10
    done
    EOT
  }
  depends_on = [azurerm_public_ip.main]
}

resource "null_resource" "execute_scripts" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/mydirectory"
    ]

    connection {
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
      host     = azurerm_public_ip.main.ip_address
      timeout  = "10m"
    }
  }
  depends_on = [null_resource.wait_for_public_ip, null_resource.wait_for_vm]
}

resource "null_resource" "wait_for_vm" {
  provisioner "local-exec" {
    command = <<EOT
    while [ "$(az vm show --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_virtual_machine.main.name} --query "provisioningState" -o tsv)" != "Succeeded" ]; do
      echo "Waiting for VM to be ready..."
      sleep 10
    done
    EOT
  }
  depends_on = [azurerm_virtual_machine.main]
}
