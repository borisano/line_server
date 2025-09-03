#!/bin/bash

# Run script for Salsify Line Server
# Starts the server with the specified file

set -e

# Check if filename argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 /path/to/myfile.txt"
    exit 1
fi

FILENAME="$1"

# Check if file exists
if [ ! -f "$FILENAME" ]; then
    echo "Error: File '$FILENAME' does not exist."
    exit 1
fi

# Check if file is readable
if [ ! -r "$FILENAME" ]; then
    echo "Error: File '$FILENAME' is not readable."
    exit 1
fi

echo "Starting Salsify Line Server..."
echo "File: $FILENAME"
echo "Server will be available at http://localhost:4567"
echo ""

# Export the filename for the application to use
export SALSIFY_FILE_PATH="$FILENAME"

# Start the server with Ruby directly instead of Puma directly
bundle exec ruby app.rb