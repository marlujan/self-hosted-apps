#!/bin/bash
set -e

# Configuration
STACK_NAME="self-hosted-apps"
REGION="us-east-1"

echo "📊 Checking application status..."

# Check if infrastructure is deployed
echo "📋 Checking infrastructure status..."
PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Infrastructure not deployed."
    echo "Please run 'infrastructure/deploy.sh' first."
    exit 1
fi

echo "✅ Infrastructure found at IP: $PUBLIC_IP"

# Update Ansible inventory
cd ansible
echo "[docker_apps]" > inventory/hosts.ini
echo "$PUBLIC_IP" >> inventory/hosts.ini

# Count available applications
APP_COUNT=0
for app_dir in ../*/; do
    if [ -d "$app_dir" ] && [ "$(basename "$app_dir")" != "ansible" ] && [ -f "$app_dir/app.yml" ]; then
        APP_COUNT=$((APP_COUNT + 1))
    fi
done

if [ "$APP_COUNT" -eq 0 ]; then
    echo ""
    echo "ℹ️  No applications configured yet."
    echo "Create application directories with app.yml files."
    exit 0
fi

echo ""
echo "📊 Checking status of $APP_COUNT application(s)..."
echo ""

# Run status check playbook
ansible-playbook -i inventory/hosts.ini status.yml

echo ""
echo "📋 Status check completed!"
echo ""
echo "Available commands:"
echo "  ./deploy.sh <app_name>   - Deploy specific application"
echo "  ./deploy.sh all          - Deploy all applications"
echo "  ./update.sh <app_name>   - Update specific application"
echo "  ./destroy.sh <app_name>  - Remove specific application"