locals {
  common_tags = merge(var.tags, {
    application = "peerlearn"
    managed_by  = "terraform"
  })
  address_space = "10.20.0.0/16"
}

# Holds all PeerLearn resources in one Azure lifecycle boundary.
resource "azurerm_resource_group" "peerlearn" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Provides the private address space for the VM.
resource "azurerm_virtual_network" "peerlearn" {
  name                = "${var.prefix}-vnet"
  address_space       = [local.address_space]
  location            = azurerm_resource_group.peerlearn.location
  resource_group_name = azurerm_resource_group.peerlearn.name
  tags                = local.common_tags
}

# Isolates the VM network interface inside the virtual network.
resource "azurerm_subnet" "peerlearn" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.peerlearn.name
  virtual_network_name = azurerm_virtual_network.peerlearn.name
  address_prefixes     = ["10.20.1.0/24"]
}

# Allows SSH from the administrator CIDR, web traffic, and restricted Jenkins access.
resource "azurerm_network_security_group" "peerlearn" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.peerlearn.location
  resource_group_name = azurerm_resource_group.peerlearn.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-ssh-restricted"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-jenkins-restricted"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.allowed_jenkins_cidr
    destination_address_prefix = "*"
  }
}

# Gives the VM a stable public IPv4 address and optional DNS label.
resource "azurerm_public_ip" "peerlearn" {
  name                = "${var.prefix}-public-ip"
  location            = azurerm_resource_group.peerlearn.location
  resource_group_name = azurerm_resource_group.peerlearn.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label == "" ? null : var.dns_label
  tags                = local.common_tags
}

# Connects the VM subnet and static public IP to the virtual machine.
resource "azurerm_network_interface" "peerlearn" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.peerlearn.location
  resource_group_name = azurerm_resource_group.peerlearn.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.peerlearn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.peerlearn.id
  }
}

# Applies the inbound rules to the VM network interface.
resource "azurerm_network_interface_security_group_association" "peerlearn" {
  network_interface_id      = azurerm_network_interface.peerlearn.id
  network_security_group_id = azurerm_network_security_group.peerlearn.id
}

# Runs the Ubuntu 22.04 host with SSH-key authentication and cloud-init bootstrap.
resource "azurerm_linux_virtual_machine" "peerlearn" {
  name                            = "${var.prefix}-vm"
  computer_name                   = "peerlearn"
  resource_group_name             = azurerm_resource_group.peerlearn.name
  location                        = azurerm_resource_group.peerlearn.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.peerlearn.id]
  custom_data                     = filebase64("${path.module}/cloud-init.sh")
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
