#!/bin/bash

# Build script for Salsify Line Server
# Installs dependencies and prepares the environment

set -e

echo "Building Salsify Line Server..."

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "Error: Ruby is not installed. Please install Ruby 3.2+ first."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
REQUIRED_VERSION="3.2.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$RUBY_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Warning: Ruby version $RUBY_VERSION detected. This project requires Ruby 3.2+."
fi

# Install bundler if not present
if ! command -v bundle &> /dev/null; then
    echo "Installing bundler..."
    gem install bundler
fi

# Install dependencies
echo "Installing dependencies..."
bundle install

echo "Build completed successfully!"
echo "Use './run.sh <filename>' to start the server."