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

required_failures=()
optional_failures=()

install_awscli_fallback() {
  local arch aws_zip_url tmp_dir

  arch="$(uname -m)"
  case "$arch" in
    x86_64)
      aws_zip_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
      ;;
    aarch64|arm64)
      aws_zip_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
      ;;
    *)
      echo "⚠️  Unsupported architecture for AWS CLI v2 installer: $arch"
      return 1
      ;;
  esac

  # Ensure unzip exists for AWS CLI zip installer
  if ! command -v unzip >/dev/null 2>&1; then
    echo "📦 Installing required tool 'unzip' for AWS CLI fallback..."
    if ! apt-get install -y unzip; then
      echo "⚠️  Could not install 'unzip'."
      return 1
    fi
  fi

  tmp_dir="$(mktemp -d)"
  if [ ! -d "$tmp_dir" ]; then
    echo "⚠️  Could not create temp directory for AWS CLI install."
    return 1
  fi

  echo "⬇️  Downloading AWS CLI v2 from official source..."
  if ! curl -fsSL "$aws_zip_url" -o "$tmp_dir/awscliv2.zip"; then
    echo "⚠️  Download of AWS CLI v2 failed."
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"; then
    echo "⚠️  Could not extract AWS CLI v2 package."
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! "$tmp_dir/aws/install" --update; then
    echo "⚠️  AWS CLI v2 installer failed."
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"

  if ! command -v aws >/dev/null 2>&1; then
    echo "⚠️  AWS CLI installation completed but 'aws' command not found in PATH."
    return 1
  fi

  echo "✅ AWS CLI installed via official installer."
  return 0
}

# Read each line and install package.
# Supported syntax:
#   package-name
#   optional:package-name
while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  line="${raw_line%%#*}"
  line="$(echo "$line" | xargs)"
  [ -z "$line" ] && continue

  is_optional=false
  package="$line"
  if [[ "$line" == optional:* ]]; then
    is_optional=true
    package="${line#optional:}"
    package="$(echo "$package" | xargs)"
  fi

  [ -z "$package" ] && continue

  echo "🔄 Installing $package..."

  if [ "$package" = "awscli" ]; then
    if apt-get install -y awscli; then
      continue
    fi

    echo "⚠️  Package 'awscli' not available, trying 'aws-cli'..."
    if apt-get install -y aws-cli; then
      continue
    fi

    echo "⚠️  APT package not available. Trying official AWS CLI installer..."
    if install_awscli_fallback; then
      continue
    fi

    echo "⚠️  Could not install AWS CLI from apt repositories."
    if [ "$is_optional" = true ]; then
      optional_failures+=("awscli")
      continue
    fi
    required_failures+=("awscli")
    continue
  fi

  if ! apt-get install -y "$package"; then
    if [ "$is_optional" = true ]; then
      echo "⚠️  Optional dependency '$package' could not be installed."
      optional_failures+=("$package")
      continue
    fi
    echo "❌ Error installing required dependency '$package'."
    required_failures+=("$package")
  fi
done < "$DEPENDENCIES_FILE"

if [ ${#required_failures[@]} -gt 0 ]; then
  echo "❌ Required dependencies failed: ${required_failures[*]}"
  exit 1
fi

if [ ${#optional_failures[@]} -gt 0 ]; then
  echo "⚠️  Optional dependencies not installed: ${optional_failures[*]}"
  echo "ℹ️  You can still use backup, FTP, WebDAV, and NAS features."
  echo "ℹ️  S3 upload requires AWS CLI ('aws' command)."
fi

echo "✅ Dependency installation completed."