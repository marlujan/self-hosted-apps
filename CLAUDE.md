# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing multiple Docker applications on shared AWS infrastructure. It uses CloudFormation for infrastructure provisioning and Ansible for application lifecycle management, enabling efficient multi-app hosting with individual domain support and automated SSL certificates.

## Architecture

The system consists of two main layers:

1. **Infrastructure Layer** (`infrastructure/`): AWS CloudFormation template that provisions VPC, EC2 instance, security groups, and networking. Ansible roles configure the base system (Docker, Nginx, Certbot).

2. **Application Layer** (`apps/`): Ansible-based deployment system that manages Docker containers, Nginx configurations, and SSL certificates for individual applications.

### Key Components
- **Nginx Reverse Proxy**: Routes traffic based on domain to appropriate Docker containers
- **Let's Encrypt SSL**: Automated certificate provisioning per domain  
- **Port Management**: Centralized allocation system prevents port conflicts
- **YAML Configuration**: Declarative app definitions with validation

## Common Commands

### Infrastructure Management
```bash
# Deploy AWS infrastructure (run first)
cd infrastructure
./deploy.sh

# Remove AWS infrastructure (destructive!)
./destroy.sh
```

### Application Management
```bash
cd apps

# Deploy specific application
./deploy.sh <app_name>

# Deploy all applications
./deploy.sh all

# Update application with latest Docker image
./update.sh <app_name>

# Remove application completely
./destroy.sh <app_name>

# Check status of all applications
./status.sh
```

### Direct Ansible Commands
```bash
cd apps/ansible

# Deploy single app
ansible-playbook -i inventory/hosts.ini playbooks/deploy_app.yml -e "app_name=readeck"

# Check status
ansible-playbook -i inventory/hosts.ini playbooks/status.yml

# Update app
ansible-playbook -i inventory/hosts.ini playbooks/update_app.yml -e "app_name=readeck"
```

## Adding New Applications

1. **Create configuration file**:
   ```bash
   cd apps/ansible/apps_config
   cp example-nextapp.yml myapp.yml
   ```

2. **Configure application** in `myapp.yml`:
   - Set unique `app_name`, `domain_name`, `docker_image`
   - Choose unique `container_port` (8000-8999 range)
   - Configure environment variables, volumes, health checks

3. **Update port allocation** in `apps/ansible/inventory/group_vars/docker_apps.yml`:
   ```yaml
   allocated_ports:
     readeck: 8000
     myapp: 8001  # Add your app with unique port
   ```

4. **Deploy**:
   ```bash
   cd apps
   ./deploy.sh myapp
   ```

## Application Configuration Schema

Applications are defined in YAML files in `apps/ansible/apps_config/`:

### Required Fields
- `app_name`: Unique identifier for the application
- `domain_name`: FQDN that will route to this application
- `container_port`: Unique port number (must be added to `docker_apps.yml`)
- `docker_image`: Docker image reference with tag
- `app_directory`: Directory path on the server

### Optional Fields
- `user_email`: Email for Let's Encrypt SSL certificates
- `container_name`: Docker container name (defaults to app_name)
- `restart_policy`: Docker restart policy (default: unless-stopped)
- `environment_vars`: Array of environment variable strings
- `volumes`: Array of Docker volume mount strings
- `healthcheck`: Container health check configuration
- `nginx_config`: Nginx-specific settings (body size, timeouts, headers)
- `ssl_enabled`: Enable/disable SSL certificate (default: true)
- `auto_start`: Start container on deployment (default: true)

## Prerequisites

- AWS CLI configured with appropriate permissions
- EC2 KeyPair created in target region
- Ansible installed with `community.docker` collection
- Domain names with configurable DNS (A records must point to infrastructure IP)

## Infrastructure Configuration

Before deployment, update `infrastructure/deploy.sh` with your settings:
- `KEY_NAME`: Your EC2 KeyPair name
- `YOUR_IP`: Your IP address for SSH access (CIDR notation)
- `PEM_FILE_PATH`: Path to your private key file

## Port Management

Port conflicts are prevented through centralized tracking in `apps/ansible/inventory/group_vars/docker_apps.yml`. Always use unique ports in the 8000-8999 range and update this file when adding new applications.

## Troubleshooting

### Infrastructure Issues
- Verify AWS CLI credentials and permissions
- Check CloudFormation stack status in AWS console
- Ensure EC2 KeyPair exists in the target region

### Application Issues
- Verify DNS A records point to the correct IP
- Check port uniqueness in `docker_apps.yml`
- Validate YAML configuration syntax
- Check Docker image availability
- Verify container health check endpoints work

### Common Commands for Debugging
```bash
# SSH to server
ssh -i ~/.ssh/your-key.pem ec2-user@<SERVER_IP>

# Check containers
docker ps
docker logs <container_name>

# Check Nginx
sudo nginx -t
sudo systemctl status nginx

# Check SSL certificates
sudo certbot certificates
```

## Security Notes

- SSH access is restricted to the specified IP address in `YOUR_IP`
- Only HTTP/HTTPS ports are open to the internet
- All applications run in isolated Docker containers
- SSL certificates are automatically managed by Let's Encrypt
- Use specific Docker image tags in production, avoid `latest`