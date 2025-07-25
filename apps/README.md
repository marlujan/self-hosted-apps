# Docker Apps Management

This directory contains Ansible-based management for Docker applications deployed on shared infrastructure.

## Quick Start

1. **Deploy Infrastructure First** (if not already done):
   ```bash
   cd ../infrastructure
   ./deploy.sh
   ```

2. **Deploy an Application**:
   ```bash
   ./deploy.sh readeck
   ```

3. **Check Status**:
   ```bash
   ./status.sh
   ```

## Available Commands

- `./deploy.sh <app_name>` - Deploy specific application
- `./deploy.sh all` - Deploy all applications
- `./update.sh <app_name>` - Update specific application
- `./destroy.sh <app_name>` - Remove specific application
- `./status.sh` - Check status of all applications

## Adding New Applications

1. **Create App Configuration**:
   ```bash
   cp ansible/apps_config/example-nextapp.yml ansible/apps_config/myapp.yml
   ```

2. **Edit Configuration**:
   - Update `app_name`, `domain_name`, `docker_image`
   - Choose unique `container_port` (check `inventory/group_vars/docker_apps.yml`)
   - Configure environment variables, volumes, etc.

3. **Update Port Allocation**:
   Edit `ansible/inventory/group_vars/docker_apps.yml` to add your app's port.

4. **Deploy**:
   ```bash
   ./deploy.sh myapp
   ```

## Project Structure

```
apps/
├── deploy.sh                 # Main deployment script
├── update.sh                 # Update applications
├── destroy.sh                # Remove applications
├── status.sh                 # Check application status
└── ansible/                  # Ansible configuration
    ├── inventory/
    │   ├── hosts.ini         # Generated server inventory
    │   └── group_vars/       # Global variables
    ├── roles/
    │   ├── docker_app/       # Generic Docker app deployment
    │   ├── nginx_config/     # Nginx configuration
    │   └── ssl_cert/         # SSL certificate management
    ├── playbooks/
    │   ├── deploy_app.yml    # Deploy single app
    │   ├── deploy_all.yml    # Deploy all apps
    │   ├── update_app.yml    # Update single app
    │   ├── remove_app.yml    # Remove single app
    │   └── status.yml        # Check app status
    └── apps_config/
        ├── readeck.yml       # Readeck configuration
        └── example-*.yml     # Example configurations
```

## Configuration Format

Each application is configured with a YAML file in `ansible/apps_config/`:

```yaml
app_name: myapp
domain_name: myapp.example.com
user_email: admin@example.com
container_port: 8001  # Must be unique!
app_directory: "/home/ec2-user/apps/myapp"

docker_image: "nginx:alpine"
container_name: myapp
restart_policy: unless-stopped

environment_vars:
  - "ENV=production"

volumes:
  - "myapp-data:/app/data"

healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8001/health"]
  interval: 30s
  timeout: 5s
  retries: 3

nginx_config:
  client_max_body_size: 50M
  proxy_timeout: 30s

ssl_enabled: true
auto_start: true
```

## Port Management

Ports are tracked in `ansible/inventory/group_vars/docker_apps.yml`:

```yaml
allocated_ports:
  readeck: 8000
  nextapp: 8001
  anotherapp: 8002
```

Always use unique ports to avoid conflicts!

## Prerequisites

- Infrastructure must be deployed first
- AWS CLI configured
- Ansible installed with `community.docker` collection
- DNS A records pointing to infrastructure IP

## Troubleshooting

1. **Check infrastructure**:
   ```bash
   ./status.sh
   ```

2. **View Ansible logs**:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.ini playbooks/status.yml -v
   ```

3. **SSH to server**:
   ```bash
   ssh -i ~/.ssh/docker-apps-1.pem ec2-user@<SERVER_IP>
   ```

4. **Check Docker containers**:
   ```bash
   docker ps
   docker logs <container_name>
   ```