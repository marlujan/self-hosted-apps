#!/bin/bash
set -e

# Configuration
STACK_NAME="docker-apps-stack"
REGION="us-east-1"

# Function to display usage
usage() {
    echo "Usage: $0 <app_name> [--yes]"
    echo ""
    echo "Arguments:"
    echo "  app_name    Name of application to remove (e.g., readeck)"
    echo "  --yes       Automatically confirm removal (dangerous!)"
    echo ""
    echo "Examples:"
    echo "  $0 readeck        # Remove Readeck with confirmation"
    echo "  $0 readeck --yes  # Remove Readeck without confirmation"
    echo ""
    echo "⚠️  WARNING: This will permanently delete the application and all its data!"
    exit 1
}

# Parse arguments
APP_NAME=""
AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --yes)
            AUTO_CONFIRM=true
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

echo "🔥 Starting application removal..."

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

# Check if app directory and config exists
if [ ! -d "../$APP_NAME" ] || [ ! -f "../$APP_NAME/app.yml" ]; then
    echo "❌ Error: Application directory '$APP_NAME' or 'app.yml' not found."
    echo ""
    echo "Available applications:"
    for app_dir in ../*/; do
        if [ -d "$app_dir" ] && [ "$(basename "$app_dir")" != "ansible" ] && [ -f "$app_dir/app.yml" ]; then
            echo "  - $(basename "$app_dir")"
        fi
    done
    exit 1
fi

# Load and display app info
APP_DOMAIN=$(grep "^domain_name:" "../$APP_NAME/app.yml" | awk '{print $2}')
APP_DIR="/home/ec2-user/apps/$APP_NAME"

echo "🔥 Removing application: $APP_NAME"
echo "📋 Application details:"
echo "  Name: $APP_NAME"
echo "  Domain: $APP_DOMAIN"
echo "  Directory: $APP_DIR"
echo ""
echo "⚠️  WARNING: This will permanently delete:"
echo "  - Docker containers and volumes"
echo "  - Application data directory"
echo "  - Nginx configuration"
echo "  - SSL certificates"
echo ""

if [ "$AUTO_CONFIRM" = false ]; then
    read -p "Are you absolutely sure you want to remove $APP_NAME? Type 'DELETE' to confirm: " confirmation
    if [ "$confirmation" != "DELETE" ]; then
        echo "Removal cancelled."
        exit 0
    fi
fi

# Run removal playbook
echo "🔥 Proceeding with removal..."
if [ "$AUTO_CONFIRM" = true ]; then
    # Override the pause task in the playbook
    ansible-playbook -i inventory/hosts.ini playbooks/remove_app.yml -e "app_name=$APP_NAME" -e "ansible_pause_prompt_timeout=1"
else
    ansible-playbook -i inventory/hosts.ini playbooks/remove_app.yml -e "app_name=$APP_NAME"
fi

echo ""
echo "✅ Application $APP_NAME has been completely removed!"
echo "ℹ️  Remember to:"
echo "  - Update your DNS records to remove the A record for $APP_DOMAIN"
echo "  - Remove the app directory if no longer needed: ../$APP_NAME/"