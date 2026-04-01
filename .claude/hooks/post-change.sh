#!/bin/bash

echo "🔍 Running Terraform safety checks..."

# Move into terraform folder if exists
if [ -d "terraform" ]; then
  cd terraform || exit 1

  echo "➡️ Running terraform fmt..."
  terraform fmt -recursive

  echo "➡️ Running terraform validate..."
  terraform validate

  echo "➡️ Running terraform plan..."
  terraform plan -input=false

  echo "✅ Terraform checks completed"
else
  echo "⚠️ No terraform folder found, skipping checks"
fi
