# Terraform Azure Development Environment Setup

This repository contains Terraform code for creating a development environment in Microsoft Azure. This environment includes a Virtual Network, Subnet, Network Security Group, Public IP, Network Interface, and a Linux Virtual Machine. These resources are defined in code to ensure consistency and ease of provisioning.
![Azure Logo](https://example.com/azure-logo.png)

## Prerequisites

Before you begin, make sure you have the following prerequisites:

- [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
- An Azure subscription. If you don't have one, you can [create a free Azure account](https://azure.com/free).

## Configuration

### Terraform Providers

This Terraform configuration uses the Azure provider from HashiCorp. It's configured in the `providers.tf` file:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}
```

### Azure Provider Configuration

The Azure provider is configured with the following block in `main.tf`:

```hcl
provider "azurerm" {
  features {}
}
```

## Resources

### Resource Group

A resource group named "mtc1" is created to organize the Azure resources:

```hcl
resource "azurerm_resource_group" "mtc" {
  name     = "mtc1"
  location = "West Europe"
  tags = {
    environment = "dev"
  }
}
```

### Virtual Network

A virtual network named "net1" is defined within the resource group:

```hcl
resource "azurerm_virtual_network" "net1" {
  name                = "net1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.mtc.location
  resource_group_name = azurerm_resource_group.mtc.name
  tags = {
    environment = "dev"
  }
}
```

### Subnet

A subnet named "sub1" is defined within the virtual network:

```hcl
resource "azurerm_subnet" "sub1" {
  name                 = "sub1"
  resource_group_name  = azurerm_resource_group.mtc.name
  virtual_network_name = azurerm_virtual_network.net1.name
  address_prefixes     = ["10.0.128.0/18"]
}
```

### Network Security Group

A network security group (NSG) named "sec" is created:

```hcl
resource "azurerm_network_security_group" "sec" {
  name                = "sec"
  location            = azurerm_resource_group.mtc.location
  resource_group_name = azurerm_resource_group.mtc.name
  tags = {
    environment = "dev"
  }
}
```

### Network Security Rules

In the NSG, a rule named "rules" is defined to allow all traffic:

```hcl
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
```

### Subnet - NSG Association

The NSG is associated with the subnet:

```hcl
resource "azurerm_subnet_network_security_group_association" "link" {
  subnet_id                 = azurerm_subnet.sub1.id
  network_security_group_id = azurerm_network_security_group.sec.id
}
```

### Public IP Address

A dynamic public IP address named "publicip1" is created:

```hcl
resource "azurerm_public_ip" "publicip1" {
  name                = "publicip1"
  resource_group_name = azurerm_resource_group.mtc.name
  location            = azurerm_resource_group.mtc.location
  allocation_method   = "Dynamic"
  tags = {
    environment = "dev"
  }
}
```

### Network Interface

A network interface named "nic" is defined:

```hcl
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
```

### Virtual Machine

A Linux Virtual Machine named "vm" is created:

```hcl
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
      hostname      = self.public_ip_address,
      user          = "adminuser",
      identityfile  = "~/.ssh/azurekey"
    })
    interpreter = var.host_os == "windows" ? [ "Powershell", "-Command" ] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}
```

### Public IP Data Source

A data source retrieves information about the public IP address:

```hcl
data "azurerm_public_ip" "show_ip" {
  name = azurerm_public_ip.publicip1.name
  resource_group_name = azurerm_resource_group.mtc.name
}
```

## Output

An output displays the public IP address of the Virtual Machine:

```hcl
output "ip_address" {
  value = "${azurerm_linux_virtual_machine.vm.name} : ${data.azurerm_public_ip.show_ip.ip_address}"
}
```

## Usage

To create the development environment, follow these steps:

1. Initialize Terraform in the project directory:

   ```shell
   terraform init
   ```

2. Review and apply the Terraform plan:

   ```shell
   terraform apply
   ```

   Terraform will prompt you to confirm the changes. Type "yes" to proceed.

3. Terraform will provision the

 Azure resources based on the defined configuration.

## Cleaning Up

To destroy the resources and clean up the environment, use:

```shell
terraform destroy
```

Terraform will prompt you to confirm the destruction of the resources. Type "yes" to proceed.

## Disclaimer

This Terraform configuration is for educational purposes and should be used in a controlled environment. Be cautious when deploying resources in a production Azure environment, and make sure to follow best practices for security and cost management.
