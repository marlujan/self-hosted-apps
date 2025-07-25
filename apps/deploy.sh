#!/bin/bash
set -e

# Configuration
STACK_NAME="docker-apps-stack"
REGION="us-east-1"

# Function to display usage
usage() {
    echo "Usage: $0 [app_name|all] [--force]"
    echo ""
    echo "Arguments:"
    echo "  app_name    Deploy specific application (e.g., readeck)"
    echo "  all         Deploy all applications"
    echo "  --force     Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0 readeck          # Deploy only Readeck"
    echo "  $0 all              # Deploy all applications"
    echo "  $0 readeck --force  # Deploy Readeck without confirmation"
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
    echo "❌ Please specify an app name or 'all'"
    usage
fi

echo "🚀 Starting application deployment..."

# Check if infrastructure is deployed
echo "📋 Checking infrastructure status..."
PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Infrastructure not deployed."
    echo "Please run 'infrastructure/deploy.sh' first to set up the base infrastructure."
    exit 1
fi

echo "✅ Infrastructure found at IP: $PUBLIC_IP"

# Update Ansible inventory
echo "📝 Updating Ansible inventory..."
cd ansible
echo "[docker_apps]" > inventory/hosts.ini
echo "$PUBLIC_IP" >> inventory/hosts.ini

# Install required Ansible collections if not present
echo "📦 Checking Ansible dependencies..."
if ! ansible-galaxy collection list | grep -q community.docker; then
    echo "Installing community.docker collection..."
    ansible-galaxy collection install community.docker
fi

# Deploy based on argument
if [ "$APP_NAME" = "all" ]; then
    echo "🚀 Deploying all applications..."
    
    # List available apps
    echo "📋 Available applications:"
    find apps_config -name "*.yml" -not -name "example-*" -exec basename {} .yml \; | sort
    
    if [ "$FORCE" = false ]; then
        echo ""
        read -p "Continue with deployment of all applications? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled."
            exit 0
        fi
    fi
    
    ansible-playbook -i inventory/hosts.ini playbooks/deploy_all.yml
else
    # Check if app config exists
    if [ ! -f "apps_config/${APP_NAME}.yml" ]; then
        echo "❌ Error: Application configuration 'apps_config/${APP_NAME}.yml' not found."
        echo ""
        echo "Available applications:"
        find apps_config -name "*.yml" -not -name "example-*" -exec basename {} .yml \; | sort
        exit 1
    fi
    
    echo "🚀 Deploying application: $APP_NAME"
    
    if [ "$FORCE" = false ]; then
        # Load and display app info
        APP_DOMAIN=$(grep "^domain_name:" "apps_config/${APP_NAME}.yml" | awk '{print $2}')
        APP_PORT=$(grep "^container_port:" "apps_config/${APP_NAME}.yml" | awk '{print $2}')
        
        echo "📋 Application details:"
        echo "  Name: $APP_NAME"
        echo "  Domain: $APP_DOMAIN"
        echo "  Port: $APP_PORT"
        echo "  Infrastructure IP: $PUBLIC_IP"
        echo ""
        echo "⚠️  Make sure your domain's A record points to $PUBLIC_IP"
        echo ""
        read -p "Continue with deployment? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled."
            exit 0
        fi
    fi
    
    ansible-playbook -i inventory/hosts.ini playbooks/deploy_app.yml -e "app_name=$APP_NAME"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo "📋 You can check application status with: ./status.sh"