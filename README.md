# Self-Hosted Apps

Personal infrastructure for deploying and managing Docker applications on AWS with automated SSL certificates and reverse proxy.

## Currently Deployed

- **Readeck**: Reading list and bookmark manager
- **Twenty CRM**: Open-source CRM system

## Quick Start

### Deploy Infrastructure
```bash
cd infrastructure
./deploy.sh
```

### Manage Applications
```bash
cd apps

# Deploy specific app
./deploy.sh readeck
./deploy.sh twenty

# Deploy all apps
./deploy.sh all

# Update app with latest images
./update.sh readeck

# Check status
./status.sh

# Remove app
./destroy.sh readeck
```

## Adding New Apps

1. Create app directory with `docker-compose.yml` and `app.yml`
2. Deploy: `./deploy.sh myapp`

See `CLAUDE.md` for detailed configuration and troubleshooting.
