# Multi-App Docker Infrastructure Specification

## 1. Overview

This project provides Infrastructure as Code (IaC) for deploying and managing multiple Docker applications on shared AWS infrastructure. The system uses CloudFormation for infrastructure provisioning and Ansible for application lifecycle management, enabling efficient multi-app hosting with individual domain support and automated SSL certificates.

### Key Features
- **Shared Infrastructure**: Cost-effective single EC2 instance hosting multiple applications
- **Ansible-Based Management**: Declarative application deployment and configuration
- **Multi-Domain Support**: Each application can have its own domain with SSL certificates
- **Automated SSL**: Let's Encrypt certificates with automatic renewal
- **Port Management**: Centralized port allocation to prevent conflicts
- **Idempotent Operations**: Consistent deployment state management

### Target Audience
- DevOps engineers managing small to medium-scale application deployments
- Developers needing cost-effective hosting for multiple projects
- Teams requiring reproducible infrastructure and application deployment

## 2. Architecture

### 2.1 System Architecture

```
┌─────────────────┐    ┌─────────────────────────────────────────┐
│   Development   │    │              AWS Cloud                  │
│   Environment   │    │                                         │
│                 │    │  ┌─────────────────────────────────────┐│
│ ┌─────────────┐ │    │  │             VPC                     ││
│ │Infrastructure│ │────┼──┤          10.0.0.0/16               ││
│ │CloudFormation│ │    │  │                                     ││
│ └─────────────┘ │    │  │  ┌─────────────────────────────────┐││
│                 │    │  │  │        Public Subnet            │││
│ ┌─────────────┐ │    │  │  │       10.0.1.0/24              │││
│ │   Ansible   │ │────┼──┼──┤                                 │││
│ │ App Manager │ │    │  │  │  ┌─────────────────────────────┐│││
│ └─────────────┘ │    │  │  │  │        EC2 Instance         ││││
│                 │    │  │  │  │                             ││││
└─────────────────┘    │  │  │  │  ┌─────────┐ ┌─────────────┐││││
                       │  │  │  │  │  Nginx  │ │   Docker    ││││
External Traffic       │  │  │  │  │ (Proxy) │ │ Containers  ││││
      ↓                │  │  │  │  │         │ │             ││││
┌─────────────┐        │  │  │  │  │ ┌─────┐ │ │ ┌─────────┐ ││││
│   Domain    │────────┼──┼──┼──┼──┤►│App1 │ │ │ │ App1    │ ││││
│   DNS       │        │  │  │  │  │ │:80  │ │ │ │ :8000   │ ││││
└─────────────┘        │  │  │  │  │ └─────┘ │ │ └─────────┘ ││││
                       │  │  │  │  │ ┌─────┐ │ │ ┌─────────┐ ││││
                       │  │  │  │  │ │App2 │ │ │ │ App2    │ ││││
                       │  │  │  │  │ │:80  │ │ │ │ :8001   │ ││││
                       │  │  │  │  │ └─────┘ │ │ └─────────┘ ││││
                       │  │  │  │  └─────────┘ └─────────────┘││││
                       │  │  │  └─────────────────────────────┘│││
                       │  │  └─────────────────────────────────┘││
                       │  └─────────────────────────────────────┘│
                       └─────────────────────────────────────────┘
```

### 2.2 Component Overview

**Infrastructure Layer:**
- **AWS CloudFormation**: Provisions VPC, EC2, security groups, and networking
- **Ansible Infrastructure Roles**: Configures base system (Docker, Nginx, Certbot)

**Application Layer:**
- **Ansible Application Roles**: Manages Docker containers, Nginx configs, SSL certificates
- **YAML Configuration**: Declarative app definitions with validation
- **Port Management**: Centralized allocation to prevent conflicts

**Network Layer:**
- **Nginx Reverse Proxy**: Routes traffic based on domain to appropriate containers
- **Let's Encrypt SSL**: Automated certificate provisioning per domain
- **Security Groups**: Controlled access (SSH restricted, HTTP/HTTPS open)

### 2.3 Data Flow

1. **Infrastructure Deployment**: CloudFormation creates AWS resources
2. **Base Configuration**: Ansible installs Docker, Nginx, Certbot on EC2
3. **Application Deployment**: Ansible deploys containers based on YAML configs
4. **Traffic Routing**: DNS → EIP → Nginx → Docker containers
5. **SSL Termination**: Nginx handles HTTPS with Let's Encrypt certificates

## 3. Project Structure

```
├── infrastructure/                    # Infrastructure management
│   ├── cloudformation.yaml           # AWS resource definitions
│   ├── deploy.sh                      # Infrastructure deployment script
│   ├── destroy.sh                     # Infrastructure teardown script
│   └── ansible/                       # Base system configuration
│       ├── ansible.cfg                # Ansible configuration
│       ├── inventory.ini              # Server inventory (generated)
│       ├── playbook.yml               # Infrastructure setup playbook
│       └── roles/                     # Infrastructure roles
│           ├── common/                # System updates
│           ├── docker/                # Docker installation
│           ├── nginx/                 # Nginx base setup
│           └── certbot/               # SSL tools installation
├── apps/                              # Application management
│   ├── deploy.sh                      # Application deployment script
│   ├── update.sh                      # Application update script
│   ├── destroy.sh                     # Application removal script
│   ├── status.sh                      # Application status checker
│   ├── README.md                      # Application management guide
│   └── ansible/                       # Application deployment system
│       ├── ansible.cfg                # App-specific Ansible config
│       ├── inventory/                 # Dynamic inventory
│       │   └── group_vars/            # Global app variables
│       ├── roles/                     # Application deployment roles
│       │   ├── docker_app/            # Generic Docker app deployment
│       │   ├── nginx_config/          # Nginx configuration management
│       │   └── ssl_cert/              # SSL certificate management
│       ├── playbooks/                 # Application lifecycle playbooks
│       │   ├── deploy_app.yml         # Single app deployment
│       │   ├── deploy_all.yml         # Multi-app deployment
│       │   ├── update_app.yml         # Application updates
│       │   ├── remove_app.yml         # Application removal
│       │   └── status.yml             # Status checking
│       └── apps_config/               # Application definitions
│           ├── readeck.yml            # Example: Readeck configuration
│           └── example-nextapp.yml    # Template for new apps
└── SPECIFICATION.md                   # This document
```

## 4. Infrastructure Management

### 4.1 AWS CloudFormation

**Template Location**: `infrastructure/cloudformation.yaml`

**Parameters:**
- `KeyName`: EC2 KeyPair name for SSH access
- `YourIP`: Source IP address for SSH access (CIDR notation)

**Resources Created:**
- **VPC**: 10.0.0.0/16 with DNS support enabled
- **Public Subnet**: 10.0.1.0/24 with auto-assign public IP
- **Internet Gateway**: Provides internet connectivity
- **Route Table**: Routes traffic to internet gateway
- **Security Group**: Allows SSH (restricted), HTTP/HTTPS (open)
- **EC2 Instance**: t2.micro (Free Tier) with Amazon Linux 2023
- **EBS Volume**: 20GB persistent storage
- **Elastic IP**: Static public IP address

**Outputs:**
- `InstanceId`: EC2 instance identifier
- `PublicIP`: Elastic IP for DNS configuration
- `PublicDNS`: Instance public DNS name

### 4.2 Base System Configuration

**Ansible Roles** (`infrastructure/ansible/roles/`):

**Common Role:**
- Updates all system packages to latest versions
- Ensures system security patches

**Docker Role:**
- Installs Docker engine via dnf
- Configures Docker service (enabled/started)
- Adds ec2-user to docker group
- Downloads Docker Compose binary

**Nginx Role:**
- Installs Nginx web server
- Creates application directory structure
- Configures basic Nginx service

**Certbot Role:**
- Installs Certbot and Nginx plugin
- Prepares system for SSL certificate management

### 4.3 Security Configuration

**Network Security:**
- SSH access restricted to specified IP address
- HTTP/HTTPS traffic open for web applications
- Internal Docker network isolation

**System Security:**
- Regular system updates via common role
- Non-root user (ec2-user) for Docker operations
- Key-based SSH authentication only

## 5. Application Management

### 5.1 Ansible-Based Deployment

Applications are managed through a comprehensive Ansible system providing:

**Deployment Operations:**
- `./deploy.sh <app_name>` - Deploy specific application
- `./deploy.sh all` - Deploy all configured applications
- `./update.sh <app_name>` - Update application with latest image
- `./destroy.sh <app_name>` - Remove application completely
- `./status.sh` - Check status of all applications

**Key Features:**
- **Idempotent Operations**: Safe to run multiple times
- **Validation**: Configuration and port conflict checking
- **Health Monitoring**: Container and application health verification
- **Rollback Safety**: Backup configurations before changes

### 5.2 Application Configuration

Applications are defined in YAML files located in `apps/ansible/apps_config/`:

**Configuration Schema:**
```yaml
# Required Fields
app_name: string              # Unique application identifier
domain_name: string           # FQDN for the application
container_port: integer       # Unique port number
docker_image: string          # Docker image reference
app_directory: string         # Application directory path

# Optional Fields
user_email: string            # Email for SSL certificates
container_name: string        # Docker container name
restart_policy: string        # Docker restart policy
environment_vars: [string]    # Environment variables
volumes: [string]            # Docker volume mounts
healthcheck: object          # Container health check config
nginx_config: object         # Nginx-specific settings
ssl_enabled: boolean         # Enable/disable SSL
auto_start: boolean          # Start on deployment
```

**Example Configuration:**
```yaml
app_name: readeck
domain_name: readeck.example.com
user_email: admin@example.com
container_port: 8000
app_directory: "/home/ec2-user/apps/readeck"
docker_image: "codeberg.org/readeck/readeck:latest"
container_name: readeck
restart_policy: unless-stopped
environment_vars:
  - "READECK_LOG_LEVEL=debug"
  - "READECK_SERVER_HOST=0.0.0.0"
  - "READECK_SERVER_PORT=8000"
volumes:
  - "readeck-data:/readeck"
healthcheck:
  test: ["CMD", "/bin/readeck", "healthcheck", "-config", "config.toml"]
  interval: 30s
  timeout: 2s
  retries: 3
nginx_config:
  client_max_body_size: 100M
  proxy_timeout: 60s
ssl_enabled: true
auto_start: true
```

### 5.3 Role System

**Docker App Role** (`apps/ansible/roles/docker_app/`):
- Creates application directory structure
- Validates port allocation and prevents conflicts
- Generates Docker Compose configuration from template
- Manages container lifecycle (pull, start, stop)
- Performs health checks and validation

**Nginx Config Role** (`apps/ansible/roles/nginx_config/`):
- Generates app-specific Nginx virtual host configuration
- Configures reverse proxy to application container
- Adds security headers and custom directives
- Validates configuration and safely reloads Nginx

**SSL Cert Role** (`apps/ansible/roles/ssl_cert/`):
- Requests Let's Encrypt certificates via Certbot
- Configures automatic HTTPS redirect
- Sets up certificate renewal cron jobs
- Handles certificate updates and renewals

## 6. Deployment Guide

### 6.1 Initial Setup

**Prerequisites:**
- AWS CLI configured with appropriate permissions
- EC2 KeyPair created in target region
- Ansible installed with `community.docker` collection
- Domain names with configurable DNS

**Infrastructure Deployment:**
```bash
# 1. Deploy AWS infrastructure
cd infrastructure
./deploy.sh

# 2. Note the public IP from output
# 3. Configure DNS A records for all app domains to point to this IP
```

**Configuration Updates:**
```bash
# Update infrastructure/deploy.sh variables:
KEY_NAME="your-keypair-name"
YOUR_IP="your.ip.address/32"
PEM_FILE_PATH="~/.ssh/your-keypair.pem"
```

### 6.2 Application Deployment

**Single Application:**
```bash
cd apps

# Deploy specific application
./deploy.sh readeck

# Check deployment status
./status.sh
```

**Multiple Applications:**
```bash
# Deploy all configured applications
./deploy.sh all

# Deploy specific applications in sequence
./deploy.sh readeck
./deploy.sh nextapp
```

**Deployment Process:**
1. Validates infrastructure availability
2. Updates Ansible inventory with server IP
3. Loads application configuration from YAML
4. Validates port conflicts and requirements
5. Deploys Docker container with health checks
6. Configures Nginx virtual host
7. Requests SSL certificate via Certbot
8. Verifies application accessibility

### 6.3 Management Operations

**Application Updates:**
```bash
# Update specific application
./update.sh readeck

# Process: pulls latest image, recreates container, verifies health
```

**Application Removal:**
```bash
# Remove application (with confirmation)
./destroy.sh readeck

# Removes: containers, volumes, nginx config, SSL certificates
```

**Status Monitoring:**
```bash
# Check all applications
./status.sh

# Shows: container status, health checks, nginx config, SSL certificates
```

## 7. Configuration Reference

### 7.1 Infrastructure Variables

**CloudFormation Parameters** (`infrastructure/cloudformation.yaml`):
```yaml
KeyName: 
  Type: AWS::EC2::KeyPair::KeyName
  Description: EC2 KeyPair for SSH access

YourIP:
  Type: String
  Description: Source IP for SSH access (CIDR notation)
  Pattern: (\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})
```

**Ansible Variables** (`infrastructure/ansible/group_vars/all.yml`):
```yaml
apps_base_directory: /home/ec2-user/apps
default_user_email: admin@example.com
ssl_default_enabled: true
docker_compose_version: '3.8'
default_restart_policy: unless-stopped
stack_name: docker-apps-stack
aws_region: us-east-1
```

### 7.2 Application Schema

**Required Fields:**
- `app_name`: Unique identifier (used for container, nginx config)
- `domain_name`: Fully qualified domain name
- `container_port`: Unique port number (tracked in port allocation)
- `docker_image`: Docker image reference with tag
- `app_directory`: Application directory path on server

**Optional Fields:**
- `user_email`: Email for Let's Encrypt registration
- `container_name`: Docker container name (defaults to app_name)
- `restart_policy`: Docker restart policy (default: unless-stopped)
- `environment_vars`: Array of environment variable strings
- `volumes`: Array of Docker volume mount strings
- `healthcheck`: Container health check configuration
- `nginx_config`: Nginx-specific configuration options
- `ssl_enabled`: Enable/disable SSL certificate (default: true)
- `auto_start`: Start container on deployment (default: true)

**Port Management:**
Ports are tracked in `apps/ansible/inventory/group_vars/docker_apps.yml`:
```yaml
allocated_ports:
  readeck: 8000
  nextapp: 8001
  # Add new applications here with unique ports
```

### 7.3 Environment Configuration

**Development Environment:**
```bash
# Use different stack names and regions for isolation
STACK_NAME="docker-apps-dev"
REGION="us-west-2"
```

**Production Environment:**
```bash
# Use production-appropriate instance types and storage
# Modify infrastructure/cloudformation.yaml:
InstanceType: t3.small  # Instead of t2.micro
VolumeSize: 50         # Instead of 20GB
```

## 8. Operations

### 8.1 Monitoring

**Application Health Checks:**
```bash
# Automated health checks via Ansible
./status.sh

# Manual container inspection
ssh -i ~/.ssh/keypair.pem ec2-user@<PUBLIC_IP>
docker ps
docker logs <container_name>
```

**System Monitoring:**
```bash
# System resources
htop
df -h
docker system df

# Nginx status
systemctl status nginx
nginx -t

# SSL certificate status
certbot certificates
```

### 8.2 Maintenance

**Regular Tasks:**
```bash
# Update system packages (via infrastructure)
cd infrastructure/ansible
ansible-playbook -i inventory.ini playbook.yml

# Update applications
cd ../../apps
./update.sh <app_name>

# Check SSL certificate renewal
sudo certbot renew --dry-run
```

**Backup Considerations:**
- Application data stored in Docker volumes
- EBS volume configured with `DeleteOnTermination: false`
- SSL certificates auto-renewed by Certbot
- Configuration stored in Git repository

### 8.3 Troubleshooting

**Common Issues:**

**Port Conflicts:**
```bash
# Error: Port already allocated
# Solution: Check apps/ansible/inventory/group_vars/docker_apps.yml
# Update allocated_ports and use unique port number
```

**SSL Certificate Failures:**
```bash
# Error: Certbot certificate request failed
# Check: DNS A record points to correct IP
# Check: Domain is accessible via HTTP first
# Debug: sudo certbot --nginx -d domain.com --dry-run
```

**Container Health Check Failures:**
```bash
# Check container logs
docker logs <container_name>

# Check application configuration
cat /home/ec2-user/apps/<app_name>/docker-compose.yml

# Restart container
cd /home/ec2-user/apps/<app_name>
docker-compose restart
```

**Nginx Configuration Issues:**
```bash
# Test nginx configuration
sudo nginx -t

# Check configuration files
ls -la /etc/nginx/conf.d/

# Reload nginx
sudo systemctl reload nginx
```

## 9. Development Guide

### 9.1 Adding Applications

**Step-by-Step Process:**

1. **Create Configuration File:**
   ```bash
   cd apps/ansible/apps_config
   cp example-nextapp.yml myapp.yml
   ```

2. **Configure Application:**
   ```yaml
   app_name: myapp
   domain_name: myapp.example.com
   container_port: 8002  # Choose unique port!
   docker_image: "nginx:alpine"
   # ... other configuration
   ```

3. **Update Port Allocation:**
   ```bash
   # Edit apps/ansible/inventory/group_vars/docker_apps.yml
   allocated_ports:
     readeck: 8000
     nextapp: 8001
     myapp: 8002  # Add your app
   ```

4. **Deploy Application:**
   ```bash
   ./deploy.sh myapp
   ```

**Port Selection Guidelines:**
- Use sequential ports starting from 8000
- Avoid common service ports (80, 443, 22, etc.)
- Document port usage in group_vars/docker_apps.yml

### 9.2 Customizing Roles

**Extending Docker App Role:**
```bash
# Add custom tasks to apps/ansible/roles/docker_app/tasks/main.yml
- name: Custom application setup
  # Your custom tasks here
```

**Custom Nginx Configuration:**
```yaml
# In app configuration YAML
nginx_config:
  client_max_body_size: 100M
  proxy_timeout: 60s
  additional_headers:
    - 'add_header X-App-Name "MyApp" always'
  custom_locations:
    - path: "/api"
      directives:
        - "proxy_pass http://localhost:8002/api"
```

**Custom Health Checks:**
```yaml
# In app configuration YAML
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8002/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### 9.3 Best Practices

**Configuration Management:**
- Store sensitive data in environment variables, not config files
- Use consistent naming conventions for apps and containers
- Document custom configurations in comments
- Version control all configuration changes

**Deployment Practices:**
- Test deployments in development environment first
- Use `--force` flags cautiously, prefer interactive confirmations
- Monitor application health after deployments
- Keep deployment scripts updated with infrastructure changes

**Security Practices:**
- Regularly update base system packages
- Use specific image tags, avoid `latest` in production
- Implement proper health checks for all applications
- Monitor SSL certificate expiration dates

## 10. Reference

### 10.1 Command Reference

**Infrastructure Management:**
```bash
cd infrastructure
./deploy.sh                    # Deploy AWS infrastructure
./destroy.sh                   # Remove AWS infrastructure (destructive!)
```

**Application Management:**
```bash
cd apps
./deploy.sh <app_name>         # Deploy specific application
./deploy.sh all                # Deploy all applications
./deploy.sh <app_name> --force # Deploy without confirmation
./update.sh <app_name>         # Update application
./update.sh <app_name> --force # Update without confirmation
./destroy.sh <app_name>        # Remove application (destructive!)
./destroy.sh <app_name> --yes  # Remove without confirmation (dangerous!)
./status.sh                    # Check application status
```

**Direct Ansible Commands:**
```bash
cd apps/ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy_app.yml -e "app_name=readeck"
ansible-playbook -i inventory/hosts.ini playbooks/status.yml
ansible-playbook -i inventory/hosts.ini playbooks/update_app.yml -e "app_name=readeck"
```

### 10.2 File Formats

**Application Configuration Schema** (`apps/ansible/apps_config/*.yml`):
```yaml
# Required fields
app_name: string (required)       # Unique application identifier
domain_name: string (required)    # FQDN for application
container_port: int (required)    # Unique port 8000-8999
docker_image: string (required)   # Docker image with tag
app_directory: string (required)  # Application directory path

# Optional fields
user_email: string                # Email for SSL certificates
container_name: string            # Docker container name
restart_policy: string            # Docker restart policy
environment_vars: [string]        # Environment variables
volumes: [string]                # Docker volume mounts
healthcheck:                      # Container health check
  test: [string]
  interval: string
  timeout: string
  retries: int
nginx_config:                     # Nginx configuration
  client_max_body_size: string
  proxy_timeout: string
  additional_headers: [string]
  custom_locations: [object]
ssl_enabled: boolean              # Enable SSL certificate
auto_start: boolean               # Start on deployment
```

**Docker Compose Template** (Generated):
```yaml
version: '3.8'
volumes:
  app-data:
services:
  app:
    image: <docker_image>
    container_name: <container_name>
    restart: <restart_policy>
    ports:
      - "<container_port>:<container_port>"
    volumes:
      - app-data:/app/data
    environment:
      - ENV_VAR=value
    healthcheck:
      test: ["CMD", "health-check-command"]
      interval: 30s
      timeout: 2s
      retries: 3
```

### 10.3 Error Codes

**Infrastructure Deployment Errors:**
- `Exit 1`: CloudFormation deployment failed
- `Exit 2`: AWS CLI not configured or insufficient permissions
- `Exit 3`: SSH key not found or invalid

**Application Deployment Errors:**
- `Exit 1`: Infrastructure not deployed (run infrastructure/deploy.sh first)
- `Exit 2`: Application configuration file not found
- `Exit 3`: Port conflict detected
- `Exit 4`: Docker image pull failed
- `Exit 5`: Container health check failed
- `Exit 6`: Nginx configuration test failed
- `Exit 7`: SSL certificate request failed

**Common Resolution Steps:**
1. Check AWS credentials and permissions
2. Verify DNS configuration points to correct IP
3. Ensure unique port allocation
4. Validate YAML configuration syntax
5. Check Docker image availability
6. Verify container health check endpoints