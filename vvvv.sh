#!/bin/bash
set -e

CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

# ===============================
# BANNER
# ===============================
echo -e "${PURPLE}${BOLD}"
echo -e "${CYAN}

____   ____.___ ____  __.____  __._____.___. ____   ____._____________ ____ ___  _________
\   \ /   /|   |    |/ _|    |/ _|\__  |   | \   \ /   /|   \______   \    |   \/   _____/
 \   Y   / |   |      < |      <   /   |   |  \   Y   / |   ||       _/    |   /\_____  \ 
  \     /  |   |    |  \|    |  \  \____   |   \     /  |   ||    |   \    |  / /        \
   \___/   |___|____|__ \____|__ \ / ______|    \___/   |___||____|_  /______/ /_______  /
                       \/       \/ \/                               \/                 \/

                      :: Powered by VIKKYVIRUS ::
${RESET}"

# ===============================
# 1. Install Dependencies
# ===============================
echo "[+] Installing dependencies..."
sudo apt update
sudo apt install -y \
  xserver-xorg-video-dummy \
  lxde-core lxde-common lxsession \
  screen curl unzip wget ufw x11-utils

# ===============================
# 2. Kill Old Sessions
# ===============================
echo "[+] Killing existing sessions..."
pkill -9 sunshine || true
pkill -9 cloudflared || true
pkill -9 lxsession || true
pkill -9 lxpanel || true
pkill -9 openbox || true
pkill -f "Xorg :0" || true

if screen -ls | grep -q sunshine; then
  screen -ls | grep sunshine | awk '{print $1}' | xargs -r -n 1 screen -S {} -X quit
fi

# ===============================
# 3. Install Sunshine
# ===============================
if ! command -v sunshine &>/dev/null; then
  echo "[+] Installing Sunshine..."
  wget -O /tmp/sunshine.deb \
    https://github.com/LizardByte/Sunshine/releases/download/v0.23.1/sunshine-ubuntu-22.04-amd64.deb
  sudo apt install -y /tmp/sunshine.deb
  rm /tmp/sunshine.deb
fi

# ===============================
# 4. Firewall
# ===============================
sudo ufw allow ssh
sudo ufw allow 47984/tcp
sudo ufw allow 47989/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47990/tcp
sudo ufw allow 47998:48002/udp
sudo ufw --force enable

# ===============================
# 5. Install Cloudflared
# ===============================
if ! command -v cloudflared &>/dev/null; then
  wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo apt install -y ./cloudflared-linux-amd64.deb
  rm cloudflared-linux-amd64.deb
fi

# ===============================
# 6. Dummy Xorg Config
# ===============================
sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/10-dummy.conf > /dev/null <<EOF
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    VideoRam    256000
EndSection
Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection
Section "Screen"
    Identifier  "DummyScreen"
    Device      "DummyDevice"
    Monitor     "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "1920x1080"
    EndSubSection
EndSection
EOF

# ===============================
# 7. Start Xorg + LXDE
# ===============================
sudo Xorg :0 -configdir /etc/X11/xorg.conf.d vt7 &
sleep 5
export DISPLAY=:0
lxsession &
sleep 5

# ===============================
# 8. Start Sunshine + Cloudflared
# ===============================
screen -dmS sunshine bash -c 'export DISPLAY=:0; sunshine'
screen -dmS cloudflared bash -c 'cloudflared tunnel --no-tls-verify --url https://localhost:47990 > /tmp/cloudflared.log 2>&1'
sleep 5

TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)
echo "Tunnel URL: $TUNNEL_URL"

# ==========================================================
# ===================== ADDITION (CHROME) ===================
# ==========================================================

echo "[+] Installing Google Chrome..."
if ! command -v google-chrome &>/dev/null; then
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
  echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | \
    sudo tee /etc/apt/sources.list.d/google-chrome.list
  sudo apt update
  sudo apt install -y google-chrome-stable
fi

CHROME_BASE="/home/$USER/chrome-profiles"
EXT_BASE="/home/$USER/uivision-extension"
TARGET_URL="https://delphi.gensyn.ai/market/0"

mkdir -p "$CHROME_BASE"

echo "[+] Downloading UI.Vision extension (FIXED URL)..."
if [ ! -d "$EXT_BASE" ]; then
  wget -O /tmp/uivision.zip \
    https://github.com/A9T9/RPA/releases/latest/download/ui.vision-rpa.zip
  unzip /tmp/uivision.zip -d "$EXT_BASE"
  rm /tmp/uivision.zip
fi

export DISPLAY=:0

echo "[+] Launching 20 Chrome profiles..."
for i in $(seq 1 20); do
  PROFILE_DIR="$CHROME_BASE/profile-$i"
  mkdir -p "$PROFILE_DIR"

  google-chrome \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --user-data-dir="$PROFILE_DIR" \
    --load-extension="$EXT_BASE" \
    "$TARGET_URL" &

  sleep 1
done

echo -e "${GREEN}${BOLD}
=====================================
  SETUP COMPLETE 🚀
  DESKTOP    : LXDE
  CHROME     : 20 PROFILES
  EXTENSION  : UI.Vision RPA
  WEBSITE    : Delphi Gensyn Market
=====================================
${RESET}"
