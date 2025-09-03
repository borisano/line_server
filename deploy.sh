#!/bin/bash

# Salsify Line Server Deployment Script
# Usage: ./deploy.sh [environment] [command]

set -e

ENVIRONMENT=${1:-staging}
COMMAND=${2:-deploy}

echo "🚀 Deploying Salsify Line Server to $ENVIRONMENT environment"

# Validate environment
case $ENVIRONMENT in
  staging|production)
    echo "✅ Valid environment: $ENVIRONMENT"
    ;;
  *)
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 [staging|production] [deploy|setup|rollback|logs|console|shell]"
    exit 1
    ;;
esac

# Check if Kamal is installed
if ! command -v kamal &> /dev/null; then
    echo "❌ Kamal is not installed. Installing..."
    bundle exec gem install kamal
fi

# Execute Kamal command
case $COMMAND in
  deploy)
    echo "📦 Deploying application..."
    bundle exec kamal deploy -d $ENVIRONMENT
    ;;
  setup)
    echo "🔧 Setting up deployment environment..."
    bundle exec kamal setup -d $ENVIRONMENT
    ;;
  rollback)
    echo "⏪ Rolling back deployment..."
    bundle exec kamal rollback -d $ENVIRONMENT
    ;;
  logs)
    echo "📋 Showing application logs..."
    bundle exec kamal app logs -d $ENVIRONMENT --follow
    ;;
  console)
    echo "🖥️  Opening application console..."
    bundle exec kamal app exec -d $ENVIRONMENT --interactive --reuse "bundle exec irb"
    ;;
  shell)
    echo "🐚 Opening shell..."
    bundle exec kamal app exec -d $ENVIRONMENT --interactive --reuse "/bin/sh"
    ;;
  status)
    echo "📊 Checking deployment status..."
    bundle exec kamal app details -d $ENVIRONMENT
    ;;
  *)
    echo "❌ Invalid command: $COMMAND"
    echo "Available commands: deploy, setup, rollback, logs, console, shell, status"
    exit 1
    ;;
esac

echo "✅ Operation completed successfully!"