# File: main.tf

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "azure-resource-group"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "azure-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Subnets
resource "azurerm_subnet" "public_subnet1" {
  name                 = "public-subnet1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.64.0/19"]
}

resource "azurerm_subnet" "public_subnet2" {
  name                 = "public-subnet2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.96.0/19"]
}

resource "azurerm_subnet" "private_subnet1" {
  name                 = "private-subnet1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/19"]
}

resource "azurerm_subnet" "private_subnet2" {
  name                 = "private-subnet2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.32.0/19"]
}

# Network Security Groups
resource "azurerm_network_security_group" "public_nsg" {
  name                = "public-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_nsg" {
  name                = "private-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowPostgreSQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "public_nsg_association" {
  subnet_id                 = azurerm_subnet.public_subnet1.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "private_nsg_association" {
  subnet_id                 = azurerm_subnet.private_subnet1.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

# Public IPs
resource "azurerm_public_ip" "nat_gateway_ip" {
  name                = "nat-gateway-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

# NAT Gateway
resource "azurerm_nat_gateway" "main" {
  name                = "nat-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
  
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "postgres"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  administrator_login = "postgres"
  administrator_password = "postgrespassword"
  sku_name            = "Standard_B1ms"
  storage_mb          = 32768
  version             = "16"
  private_dns_zone_id = azurerm_subnet.private_subnet1.id
  delegated_subnet_id = azurerm_subnet.private_subnet1.id

  configuration {
    name  = "log_statement"
    value = "all"
  }
}

# Virtual Machines for Node.js and Python Servers
resource "azurerm_linux_virtual_machine" "nodejs_server" {
  name                  = "nodejs-server"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.nodejs_interface.id]
  size                  = "Standard_B2s"

  admin_username = "azureuser"
  admin_password = "P@ssword123!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "python_server" {
  name                  = "python-server"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.python_interface.id]
  size                  = "Standard_B2s"

  admin_username = "azureuser"
  admin_password = "P@ssword123!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Add similar configurations for Load Balancer, Target Pools, and DNS Records
# Application Gateway for Node.js
resource "azurerm_application_gateway" "nodejs_gateway" {
  name                = "nodejs-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.public_subnet1.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.nodejs_lb.id
  }

  backend_address_pool {
    name = "nodejs-backend-pool"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "nodejs-routing-rule"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "nodejs-backend-pool"
    backend_http_settings_name = "http-settings"
  }

  backend_http_settings {
    name                  = "http-settings"
    protocol              = "Http"
    port                  = 80
    request_timeout       = 20
    cookie_based_affinity = "Disabled"
  }
}

# Application Gateway for Python
resource "azurerm_application_gateway" "python_gateway" {
  name                = "python-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.public_subnet2.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.python_lb.id
  }

  backend_address_pool {
    name = "python-backend-pool"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "python-routing-rule"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "python-backend-pool"
    backend_http_settings_name = "http-settings"
  }

  backend_http_settings {
    name                  = "http-settings"
    protocol              = "Http"
    port                  = 80
    request_timeout       = 20
    cookie_based_affinity = "Disabled"
  }
}

# Public IPs for Load Balancers
resource "azurerm_public_ip" "nodejs_lb" {
  name                = "nodejs-lb-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "python_lb" {
  name                = "python-lb-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# DNS Zones
resource "azurerm_dns_zone" "backend_postgres" {
  name                = "backend.postgres.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_zone" "backend_python" {
  name                = "backend.python.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_zone" "backend_nodejs" {
  name                = "backend.nodejs.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_zone" "backend_redis" {
  name                = "backend.redis.com"
  resource_group_name = azurerm_resource_group.main.name
}

# DNS Records
resource "azurerm_dns_a_record" "postgres" {
  name                = "postgres"
  zone_name           = azurerm_dns_zone.backend_postgres.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_postgresql_flexible_server.main.fqdn]
}

resource "azurerm_dns_a_record" "nodejs" {
  name                = "nodejs"
  zone_name           = azurerm_dns_zone.backend_nodejs.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_public_ip.nodejs_lb.ip_address]
}

resource "azurerm_dns_a_record" "python" {
  name                = "python"
  zone_name           = azurerm_dns_zone.backend_python.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_public_ip.python_lb.ip_address]
}

resource "azurerm_dns_a_record" "redis" {
  name                = "redis"
  zone_name           = azurerm_dns_zone.backend_redis.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_linux_virtual_machine.monitoring.private_ip_address]
}

# Monitoring Instance
resource "azurerm_linux_virtual_machine" "monitoring" {
  name                  = "monitoring-instance"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.monitoring.id]
  size                  = "Standard_B2s"

  admin_username = "azureuser"
  admin_password = "P@ssword123!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    Environment = "Monitoring"
  }
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = "redis-cache"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 1
  family              = "C"
  sku_name            = "Basic"

  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
}

# Network Interfaces for VMs
resource "azurerm_network_interface" "nodejs_interface" {
  name                = "nodejs-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nodejs_lb.id
  }
}

resource "azurerm_network_interface" "python_interface" {
  name                = "python-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.python_lb.id
  }
}

resource "azurerm_network_interface" "monitoring" {
  name                = "monitoring-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = null
  }
}

# Redis DNS Configuration
resource "azurerm_dns_a_record" "redis_cache" {
  name                = "redis"
  zone_name           = azurerm_dns_zone.backend_redis.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_redis_cache.main.hostname]
}

# Backend Pool Associations
resource "azurerm_application_gateway_backend_address_pool" "nodejs_backend" {
  name                = "nodejs-backend-pool"
  resource_group_name = azurerm_resource_group.main.name
  application_gateway_id = azurerm_application_gateway.nodejs_gateway.id

  backend_addresses {
    ip_address = azurerm_network_interface.nodejs_interface.private_ip_address
  }
}

resource "azurerm_application_gateway_backend_address_pool" "python_backend" {
  name                = "python-backend-pool"
  resource_group_name = azurerm_resource_group.main.name
  application_gateway_id = azurerm_application_gateway.python_gateway.id

  backend_addresses {
    ip_address = azurerm_network_interface.python_interface.private_ip_address
  }
}

# Attach VMs to Backend Pools
resource "azurerm_application_gateway_http_listener" "nodejs_listener" {
  name                           = "nodejs-listener"
  frontend_ip_configuration_name = "frontend-ip"
  frontend_port_name             = "http-port"
  protocol                       = "Http"
  resource_group_name            = azurerm_resource_group.main.name
  application_gateway_id         = azurerm_application_gateway.nodejs_gateway.id
}

resource "azurerm_application_gateway_http_listener" "python_listener" {
  name                           = "python-listener"
  frontend_ip_configuration_name = "frontend-ip"
  frontend_port_name             = "http-port"
  protocol                       = "Http"
  resource_group_name            = azurerm_resource_group.main.name
  application_gateway_id         = azurerm_application_gateway.python_gateway.id
}

# CDN Profile
resource "azurerm_cdn_profile" "nodejs_cdn" {
  name                = "nodejs-cdn-profile"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard_Microsoft" # Choose appropriate SKU

  tags = {
    Environment = "Production"
  }
}

# CDN Endpoint
resource "azurerm_cdn_endpoint" "nodejs_endpoint" {
  name                = "nodejs-cdn-endpoint"
  profile_name        = azurerm_cdn_profile.nodejs_cdn.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  origin {
    name      = "nodejs-app-gateway"
    host_name = azurerm_public_ip.nodejs_lb.ip_address # Application Gateway's public IP
    https_port = 443
  }

  is_http_allowed  = true
  is_https_allowed = true

  delivery_rule {
    name = "cors-headers-rule"
    order = 1
    actions {
      response_header_action {
        header_action = "ModifyResponseHeader"
        response_headers {
          header_name  = "Access-Control-Allow-Origin"
          header_value = "*"
          overwrite    = true
        }
        response_headers {
          header_name  = "Access-Control-Allow-Methods"
          header_value = "GET,POST,PUT,DELETE,OPTIONS"
          overwrite    = true
        }
        response_headers {
          header_name  = "Access-Control-Allow-Headers"
          header_value = "Origin, X-Requested-With, Content-Type, Accept, Authorization"
          overwrite    = true
        }
        response_headers {
          header_name  = "Access-Control-Expose-Headers"
          header_value = "Authorization, Content-Length"
          overwrite    = true
        }
      }
    }
  }

  tags = {
    Environment = "Production"
  }
}

# DNS Configuration for CDN
resource "azurerm_dns_cname_record" "cdn_dns" {
  name                = "cdn"
  zone_name           = azurerm_dns_zone.backend_nodejs.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = azurerm_cdn_endpoint.nodejs_endpoint.host_name
}

# CORS and Security Headers Configuration
resource "azurerm_cdn_custom_domain" "nodejs_custom_domain" {
  name                = "nodejs-custom-domain"
  endpoint_name       = azurerm_cdn_endpoint.nodejs_endpoint.name
  profile_name        = azurerm_cdn_profile.nodejs_cdn.name
  resource_group_name = azurerm_resource_group.main.name
  host_name           = "cdn.backend.nodejs.com" # Custom domain for the CDN
}

# Add Response Headers for CORS
resource "azurerm_cdn_rule_set" "cors_policy" {
  name                = "cdn-cors-policy"
  resource_group_name = azurerm_resource_group.main.name
  cdn_endpoint_id     = azurerm_cdn_endpoint.nodejs_endpoint.id

  rule {
    name  = "cors-policy-rule"
    order = 1

    conditions {
      request_method {
        operator = "Any"
      }
    }

    actions {
      modify_response_header {
        header_action = "Add"
        response_header {
          header_name  = "Access-Control-Allow-Origin"
          header_value = "*"
        }
      }
      modify_response_header {
        header_action = "Add"
        response_header {
          header_name  = "Access-Control-Allow-Methods"
          header_value = "GET, POST, PUT, DELETE, OPTIONS"
        }
      }
      modify_response_header {
        header_action = "Add"
        response_header {
          header_name  = "Access-Control-Allow-Headers"
          header_value = "Content-Type, Authorization, Accept, X-Requested-With"
        }
      }
    }
  }
}
