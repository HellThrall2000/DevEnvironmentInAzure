terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "mtc" {
  name     = "mtc1"
  location = "West Europe"
  tags = {
    environment = "dev"
  }
}
resource "azurerm_virtual_network" "net1" {
  name                = "net1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.mtc.location
  resource_group_name = azurerm_resource_group.mtc.name
  tags = {
    environment = "dev"
  }
}
resource "azurerm_subnet" "sub1" {
  name                 = "sub1"
  resource_group_name  = azurerm_resource_group.mtc.name
  virtual_network_name = azurerm_virtual_network.net1.name
  address_prefixes     = ["10.0.128.0/18"]

}
resource "azurerm_network_security_group" "sec" {
  name                = "sec"
  location            = azurerm_resource_group.mtc.location
  resource_group_name = azurerm_resource_group.mtc.name

  tags = {
    environment = "dev"
  }
}
resource "azurerm_network_security_rule" "rules" {
  name                        = "rules"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc.name
  network_security_group_name = azurerm_network_security_group.sec.name
}

resource "azurerm_subnet_network_security_group_association" "link" {
  subnet_id                 = azurerm_subnet.sub1.id
  network_security_group_id = azurerm_network_security_group.sec.id
}
resource "azurerm_public_ip" "publicip1" {
  name                = "publicip1"
  resource_group_name = azurerm_resource_group.mtc.name
  location            = azurerm_resource_group.mtc.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}
resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = azurerm_resource_group.mtc.location
  resource_group_name = azurerm_resource_group.mtc.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.publicip1.id
  }
  
  tags = {
    environment = "dev"
  }

}
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.mtc.name
  location            = azurerm_resource_group.mtc.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  custom_data = filebase64("custom.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile("${var.host_os}-script.tpl", {
          hostname = self.public_ip_address,
          user = "adminuser",
          identityfile = "~/.ssh/azurekey"
      })
    interpreter = var.host_os == "windows" ? [ "Powershell", "-Command" ] : ["bash", "-c"]
  }
   tags = {
    environment = "dev"
  }

}
data "azurerm_public_ip" "show_ip" {
  name = azurerm_public_ip.publicip1.name
  resource_group_name = azurerm_resource_group.mtc.name
}
output "ip_address" {
 value = "${azurerm_linux_virtual_machine.vm.name} : ${data.azurerm_public_ip.show_ip.ip_address}"
}