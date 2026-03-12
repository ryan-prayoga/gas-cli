#!/usr/bin/env bash
set -e

echo "Installing gas CLI..."

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_command() {
  command -v "$1" >/dev/null 2>&1
}

install_apt() {
  sudo apt update
  sudo apt install -y "$@"
}

echo "Checking dependencies..."

# git
if ! check_command git; then
  echo "Installing git..."
  install_apt git
fi

# sqlite3
if ! check_command sqlite3; then
  echo "Installing sqlite3..."
  install_apt sqlite3
fi

# curl
if ! check_command curl; then
  echo "Installing curl..."
  install_apt curl
fi

# node
if ! check_command node; then
  echo "Node.js not found."
  echo "Installing Node via NodeSource..."

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  install_apt nodejs
fi

# npm
if ! check_command npm; then
  echo "npm not found. Installing..."
  install_apt npm
fi

# pm2
if ! check_command pm2; then
  echo "Installing PM2..."
  sudo npm install -g pm2
fi

# gum (optional)
if ! check_command gum; then
  echo "Installing gum (optional UI)..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo tee /etc/apt/keyrings/charm.gpg >/dev/null

  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
    sudo tee /etc/apt/sources.list.d/charm.list

  sudo apt update
  install_apt gum || true
fi

echo "Linking gas command..."

sudo ln -sf "$REPO_DIR/bin/gas" /usr/local/bin/gas

chmod +x "$REPO_DIR/bin/gas"

echo ""
echo "gas CLI installed successfully!"
echo ""
echo "Test with:"
echo "  gas help"