cat > /tmp/blockassist_install.sh <<'EOF'
#!/usr/bin/env bash
set -e

echo "[1] Updating system..."
apt update -y && apt upgrade -y

echo "[2] Installing git..."
apt install git -y

echo "[3] Cloning BlockAssist..."
rm -rf blockassist
git clone https://github.com/gensyn-ai/blockassist.git

echo "[4] Entering blockassist..."
cd blockassist

echo "[5] Entering modal-login..."
cd modal-login

echo "[6] Installing dependencies..."
yarn install

echo "[7] Starting yarn dev (press CTRL+C to stop manually)..."
yarn dev

echo "[8] Going back to blockassist..."
cd ..
EOF

# make executable and run as root
chmod +x /tmp/blockassist_install.sh
sudo /bin/bash /tmp/blockassist_install.sh
