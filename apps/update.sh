#!/bin/bash
set -e

# Configuration
STACK_NAME="docker-apps-stack"
REGION="us-east-1"

# Function to display usage
usage() {
    echo "Usage: $0 <app_name> [--force]"
    echo ""
    echo "Arguments:"
    echo "  app_name    Name of application to update (e.g., readeck)"
    echo "  --force     Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0 readeck          # Update Readeck"
    echo "  $0 readeck --force  # Update Readeck without confirmation"
    exit 1
}

# Parse arguments
APP_NAME=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$APP_NAME" ]; then
                APP_NAME="$1"
            else
                echo "❌ Unknown argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

if [ -z "$APP_NAME" ]; then
    echo "❌ Please specify an app name"
    usage
fi

echo "🔄 Starting application update..."

# Check if infrastructure is deployed
echo "📋 Checking infrastructure status..."
PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Infrastructure not deployed."
    exit 1
fi

echo "✅ Infrastructure found at IP: $PUBLIC_IP"

# Update Ansible inventory
cd ansible
echo "[docker_apps]" > inventory/hosts.ini
echo "$PUBLIC_IP" >> inventory/hosts.ini

# Check if app config exists
if [ ! -f "apps_config/${APP_NAME}.yml" ]; then
    echo "❌ Error: Application configuration 'apps_config/${APP_NAME}.yml' not found."
    echo ""
    echo "Available applications:"
    find apps_config -name "*.yml" -not -name "example-*" -exec basename {} .yml \; | sort
    exit 1
fi

# Load and display app info
APP_DOMAIN=$(grep "^domain_name:" "apps_config/${APP_NAME}.yml" | awk '{print $2}')
APP_IMAGE=$(grep "^docker_image:" "apps_config/${APP_NAME}.yml" | awk '{print $2}' | tr -d '"')

echo "🔄 Updating application: $APP_NAME"
echo "📋 Application details:"
echo "  Name: $APP_NAME"
echo "  Domain: $APP_DOMAIN"
echo "  Docker Image: $APP_IMAGE"

if [ "$FORCE" = false ]; then
    echo ""
    read -p "Continue with update? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        exit 0
    fi
fi

# Run update playbook
ansible-playbook -i inventory/hosts.ini playbooks/update_app.yml -e "app_name=$APP_NAME"

echo ""
echo "✅ Update completed successfully!"
echo "📋 Application is available at: https://$APP_DOMAIN"