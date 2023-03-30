terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Configure the Microsoft Azure Resource
resource "azurerm_resource_group" "rg" {
  name     = "DEV-ENV-Resources"
  location = "EAST US"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vn" {
  name                = "DEV-ENV-Network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.123.0.0/16"]
}

# Create a subnet 
resource "azurerm_subnet" "sbn" {
  name                 = "DEV-ENV-SUBNET"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

#Create a Security Group

resource "azurerm_network_security_group""sg"{
  name = "DEV-ENV-SEC_GRP"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
#Create Network Security Rule
resource "azurerm_network_security_rule" "dev_sec_rule" {
  name                        = "DEV-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg
}

resource "azurerm_subnet_network_security_group_association" "sga" {
  subnet_id = azurerm_subnet.sbn.id
  network_security_group_id = azurerm_network_security_group.sg.id
}
#Creating a public ip  
resource "azurerm_public_ip" "dev_ip" {
  name = "DEV-PUB-IP"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  allocation_method = "Dynamic"
  
}

resource "azurerm_network_interface" "nic" {
  name = "dev-nic"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.sbn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.dev_ip.id
  }
  
}


#Creaing a VM
resource "azurerm_linux_virtual_machine" "Dev_VM" {
  name = "Dev_VM"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_B1s"
  admin_username = "adminuser"
  network_interface_ids = azurerm_network_interface.nic.id


  custom_data = filebase64("customdata.tpl")



  #ssh-keygen-t rsa ----use this command interminal to create a key pair
  admin_ssh_key {
    username ="adminuser"
    public_key = file("~/.path/key.pub")
  
  }
  os_disk {
    caching ="ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku="22.04-LTS"
    version="latest"
  }
  #Creating a Provisioner
  provisioner "local-exec" {
    command = templatefile("linux-ssh-script.tpl",{
      hostname =self.public_ip_address,
      user="adminuser",
      identityfile="~/.ssh/azkey"
    })
    interpreter = ["bash","-c"]
    
  }
}

data "azurerm_public_ip" "ip-data" {
  name=azurerm_public_ip.dev_ip.name
  resource_group_name = azurerm_resource_group.rg.name  
}
output "public_ip_address" {
  value = "${azurerm_linux_machine.DEV_VM.name}: ${data.azurerm_public_ip.ip-data.ip_address}"
}
