cat > /tmp/blockassist_pyenv_fix.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Colors (define before info)
# ----------------------------
CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

info() {
  printf "${CYAN}%s${RESET}\n" "$*"
}

# Banner (use RESET instead of undefined NC)
echo -e "${PURPLE}${BOLD}"
echo -e "${CYAN}
 
____   ____.___ ____  __.____  __._____.___. ____   ____._____________ ____ ___  _________
\\   \\ /   /|   |    |/ _|    |/ _|\\__  |   | \\   \\ /   /|   \\______   \\    |   \\/   _____/
 \\   Y   / |   |      < |      <   /   |   |  \\   Y   / |   ||       _/    |   /\\_____  \\ 
  \\     /  |   |    |  \\|    |  \\  \\____   |   \\     /  |   ||    |   \\    |  / /        \\
   \\___/   |___|____|__ \\____|__ \\ / ______|    \\___/   |___||____|_  /______/ /_______  /
                       \\/       \\/ \\/                               \\/                 \\/ 
${RESET}"
echo

# set pyenv variables
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Ensure apt packages and build deps for pyenv
info "Installing apt prerequisites for building Python (may ask for sudo password)..."
sudo apt update
sudo apt install -y build-essential curl git zlib1g-dev libssl-dev \
 libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev \
 xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev unzip

# Install Node.js LTS via NodeSource if node not present (helps npm/yarn)
if ! command -v node >/dev/null 2>&1; then
  info "Installing Node.js (LTS)..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
fi

# Ensure npm/yarn/localtunnel
if ! command -v npm >/dev/null 2>&1; then
  info "Installing npm (via apt)..."
  sudo apt install -y npm
fi
if ! command -v yarn >/dev/null 2>&1; then
  info "Installing yarn (via npm)..."
  sudo npm install -g yarn
fi
if ! command -v lt >/dev/null 2>&1; then
  info "Installing localtunnel (via npm)..."
  sudo npm install -g localtunnel
fi

# Run setup.sh if present and executable
if [[ -f setup.sh ]]; then
  info "Running setup.sh (if it exists)..."
  chmod +x setup.sh
  ./setup.sh
fi

# Install pyenv (user-level) if not present
if ! command -v pyenv >/dev/null 2>&1; then
  info "Installing pyenv for current user..."
  curl -fsSL https://pyenv.run | bash
fi

# Ensure PATH and init for current shell
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Proper init lines
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
  if command -v pyenv-virtualenv-init >/dev/null 2>&1; then
    eval "$(pyenv virtualenv-init -)"
  fi
else
  echo "ERROR: pyenv is still not available in PATH. Exiting."
  exit 2
fi

# Persist pyenv setup to ~/.bashrc (if not already present)
if ! grep -q 'PYENV_ROOT' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<'BASHRC'

# pyenv configuration (added by blockassist installer)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)"
if command -v pyenv-virtualenv-init >/dev/null 2>&1; then
  eval "$(pyenv virtualenv-init -)"
fi
BASHRC
  info "Appended pyenv init to ~/.bashrc (applies on new shells)."
fi

# Install Python 3.10.x (skip if already installed). Using 3.10.12 as stable example.
PY_VER="3.10.12"
info "Ensuring Python ${PY_VER} via pyenv (this can take some minutes)..."
pyenv install -s "${PY_VER}"
pyenv local "${PY_VER}"

# Use pyenv's python to install pip packages
info "Upgrading pip and installing required Python packages..."
pyenv exec python -m pip install --upgrade pip
pyenv exec python -m pip install psutil readchar rich || true

# Ensure screen
if ! command -v screen >/dev/null 2>&1; then
  info "Installing screen..."
  sudo apt install -y screen
fi

info "✅ Setup complete!"
echo
echo "Open a NEW terminal or run: source ~/.bashrc"
echo "Then go to your repo and run (example):"
echo "  cd ~/blockassist"
echo "  export DISPLAY=:0"
echo "  pyenv exec python run.py"
echo
EOF

chmod +x /tmp/blockassist_pyenv_fix.sh
# Run it
/bin/bash /tmp/blockassist_pyenv_fix.sh
