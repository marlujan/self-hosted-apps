# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing multiple Docker applications on shared AWS infrastructure. It uses CloudFormation for infrastructure provisioning and Ansible for application lifecycle management, enabling efficient multi-app hosting with individual domain support and automated SSL certificates.

## Architecture

The system consists of two main layers:

1. **Infrastructure Layer** (`infrastructure/`): AWS CloudFormation template that provisions VPC, EC2 instance, security groups, and networking. Ansible roles configure the base system (Docker, Nginx, Certbot).

2. **Application Layer** (`apps/`): Docker Compose-first deployment system orchestrated by Ansible. Each application is self-contained with its own Docker Compose file and configuration.

### Key Components
- **Docker Compose**: Native multi-service support using official Docker Compose files
- **Ansible Orchestration**: Manages deployment lifecycle, environment injection, and system integration
- **Nginx Reverse Proxy**: Routes traffic based on domain to appropriate Docker services
- **Let's Encrypt SSL**: Automated certificate provisioning per domain  
- **Self-Contained Apps**: Each app directory contains all deployment artifacts
- **Environment Injection**: Ansible generates `.env` files from app configurations

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

# Update application with latest Docker images
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

# Remove app
ansible-playbook -i inventory/hosts.ini playbooks/remove_app.yml -e "app_name=readeck"
```

## Adding New Applications

1. **Create application directory**:
   ```bash
   cd apps
   mkdir myapp
   ```

2. **Create Docker Compose file** in `myapp/docker-compose.yml`:
   ```yaml
   version: '3.8'
   services:
     myapp:
       image: myapp/myapp:latest
       container_name: myapp
       restart: unless-stopped
       ports:
         - "${MYAPP_PORT}:3000"
       environment:
         - NODE_ENV=${NODE_ENV}
         - DATABASE_URL=${DATABASE_URL}
   ```

3. **Create app configuration** in `myapp/app.yml`:
   ```yaml
   app_name: myapp
   domain_name: myapp.example.com
   user_email: admin@example.com
   
   services:
     myapp:
       port: 3000
       proxy_port: 8001  # Choose unique port (8000-8999)
       health_path: /health
   
   ssl_enabled: true
   
   environment:
     NODE_ENV: production
     DATABASE_URL: postgresql://localhost/myapp
     MYAPP_PORT: "{{ services.myapp.port }}"
   ```

4. **Deploy**:
   ```bash
   cd apps
   ./deploy.sh myapp
   ```

## Application Configuration Schema

Applications are defined in `app.yml` files within each app directory:

### Required Fields
- `app_name`: Unique identifier for the application
- `domain_name`: FQDN that will route to this application
- `services`: Dictionary mapping Docker Compose service names to configuration

### Service Configuration
- `port`: Internal container port
- `proxy_port`: External port for Nginx proxy (must be unique, 8000-8999 range)
- `health_path`: Health check endpoint path (optional)
- `timeout`: Health check timeout (optional)

### Optional Fields
- `user_email`: Email for Let's Encrypt SSL certificates
- `nginx`: Nginx-specific settings (body size, timeouts, headers)
- `ssl_enabled`: Enable/disable SSL certificate (default: true)
- `environment`: Dictionary of environment variables for `.env` file generation
- `compose`: Docker Compose project settings

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

Port conflicts are prevented through automatic validation during deployment. Each service's `proxy_port` must be unique across all applications. Use ports in the 8000-8999 range for external access.

## Troubleshooting

### Infrastructure Issues
- Verify AWS CLI credentials and permissions
- Check CloudFormation stack status in AWS console
- Ensure EC2 KeyPair exists in the target region

### Application Issues
- Verify DNS A records point to the correct IP
- Check port uniqueness across all `app.yml` files
- Validate YAML configuration syntax
- Check Docker image availability in Docker Compose file
- Verify container health check endpoints work
- Check `.env` file generation in app directory on server

### Common Commands for Debugging
```bash
# SSH to server
ssh -i ~/.ssh/your-key.pem ec2-user@<SERVER_IP>

# Check containers
docker ps
docker logs <container_name>
cd /home/ec2-user/apps/<app_name> && docker-compose logs

# Check Nginx
sudo nginx -t
sudo systemctl status nginx
ls -la /etc/nginx/sites-enabled/

# Check SSL certificates
sudo certbot certificates

# Check app environment files
cat /home/ec2-user/apps/<app_name>/.env
```

## Security Notes

- SSH access is restricted to the specified IP address in `YOUR_IP`
- Only HTTP/HTTPS ports are open to the internet
- All applications run in isolated Docker containers
- SSL certificates are automatically managed by Let's Encrypt
- Use specific Docker image tags in production, avoid `latest`