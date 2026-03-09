#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPENDENCIES_FILE="$SCRIPT_DIR/dependencies.txt"

# Check if dependencies file exists
if [ ! -f "$DEPENDENCIES_FILE" ]; then
  echo "❌ Error: File 'dependencies.txt' not found!"
  exit 1
fi

echo "📦 Installing dependencies from '$DEPENDENCIES_FILE'..."

# Read each line and install the package
while IFS= read -r package || [ -n "$package" ]; do
  if [ -n "$package" ] && [[ ! "$package" =~ ^# ]]; then
    echo "🔄 Installing $package..."
    apt-get install -y "$package" || { echo "❌ Error installing $package"; exit 1; }
  fi
done < "$DEPENDENCIES_FILE"

echo "✅ All dependencies successfully installed!"