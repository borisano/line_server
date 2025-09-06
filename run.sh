#!/bin/bash

# Run script for Salsify Line Server
# Starts the server with configuration from .env file or command line argument

set -e

# Check if .env file exists and load configuration
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Override with command line argument if provided
if [ $# -eq 1 ]; then
    FILENAME="$1"
    export SALSIFY_FILE_PATH="$FILENAME"
fi

# Check if SALSIFY_FILE_PATH is set
if [ -z "$SALSIFY_FILE_PATH" ]; then
    echo "Error: No file specified."
    echo "Either:"
    echo "  1. Set SALSIFY_FILE_PATH in .env file, or"
    echo "  2. Provide filename as argument: $0 <filename>"
    echo ""
    echo "Example: $0 /path/to/myfile.txt"
    exit 1
fi

# Check if file exists
if [ ! -f "$SALSIFY_FILE_PATH" ]; then
    echo "Error: File '$SALSIFY_FILE_PATH' does not exist."
    exit 1
fi

# Check if file is readable
if [ ! -r "$SALSIFY_FILE_PATH" ]; then
    echo "Error: File '$SALSIFY_FILE_PATH' is not readable."
    exit 1
fi

echo "Starting Salsify Line Server..."
echo "File: $SALSIFY_FILE_PATH"
echo "Port: ${PORT:-4567}"
echo "Memory threshold: ${MEMORY_THRESHOLD_MB:-512}MB"
echo "Server will be available at http://localhost:${PORT:-4567}"
echo ""

# Start the server with Ruby directly
bundle exec ruby app.rb