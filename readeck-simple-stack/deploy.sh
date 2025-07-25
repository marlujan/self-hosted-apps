#!/bin/bash
set -e

# --- Configuration ---
STACK_NAME="readeck-stack"
REGION="us-east-1"
KEY_NAME="readeck-1" # CHANGE THIS
YOUR_IP="189.239.72.207/32"             # CHANGE THIS
DOMAIN_NAME="readeck.migacloud.dev" # CHANGE THIS
USER_EMAIL="marlujan.hj@gmail.com"  # CHANGE THIS
PEM_FILE_PATH="~/.ssh/${KEY_NAME}.pem" # CHANGE THIS

# --- Step 1: Deploy Infrastructure with CloudFormation ---
echo "🚀 Starting CloudFormation deployment..."
aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name $STACK_NAME \
  --region $REGION \
  --parameter-overrides KeyName=$KEY_NAME YourIP=$YOUR_IP \
  --capabilities CAPABILITY_IAM

echo "✅ CloudFormation stack deployment initiated."

# --- Step 2: Get Public IP from Stack Output ---
echo "⏳ Waiting for stack to complete and retrieving public IP..."
PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Error: Could not retrieve Public IP from CloudFormation stack."
    exit 1
fi

echo "✅ Instance is running at Public IP: $PUBLIC_IP"
echo "ℹ️  ACTION REQUIRED: Point your domain's A record ($DOMAIN_NAME) to $PUBLIC_IP now."
read -p "Press [Enter] to continue after updating your DNS..."

# --- Step 3: Configure Ansible ---
echo "⚙️  Configuring Ansible..."

# Update ansible.cfg with correct key path
sed -i.bak "s|private_key_file = .*|private_key_file = ${PEM_FILE_PATH}|" ansible/ansible.cfg

# Update group_vars with domain and email
sed -i.bak -e "s/domainname: .*/domain_name: ${DOMAIN_NAME}/" \
           -e "s/user_email: .*/user_email: ${USER_EMAIL}/" \
           ansible/group_vars/all.yml

# Create dynamic inventory file
echo "[readeck_server]" > ansible/inventory.ini
echo "$PUBLIC_IP" >> ansible/inventory.ini

echo "✅ Ansible configured."

# --- Step 4: Provision Server with Ansible ---
echo "🚀 Running Ansible playbook... This may take several minutes."
# Wait a bit for the server to be fully ready for SSH
#sleep 60
cd ./ansible
ansible-playbook -i inventory.ini playbook.yml

echo "🎉 Success! Your Readeck instance is fully deployed and configured at https://${DOMAIN_NAME}"