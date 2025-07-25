#!/bin/bash
set -e

STACK_NAME="docker-apps-stack"
REGION="us-east-1"

read -p "Are you sure you want to delete the stack '$STACK_NAME'? This will destroy ALL applications! [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "🔥 Deleting CloudFormation stack '$STACK_NAME'..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

echo "⏳ Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

echo "✅ Stack deleted successfully."