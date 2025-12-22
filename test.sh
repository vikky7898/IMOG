#!/bin/bash
set -e

CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
YELLOW='\033[1;33m'
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
${YELLOW}                      :: Powered by VIKKYVIRUS ::
${RESET}"

# ===== 1. Install Dependencies =====
echo "[+] Installing dependencies..."
sudo apt update
sudo apt install -y \
  xserver-xorg-video-dummy \
  lxde-core lxde-common lxsession \
  screen curl unzip wget ufw

echo "[+] Killing existing Sunshine, Cloudflared, LXDE, Xorg, and screen sessions..."

pkill -9 sunshine 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
pkill -9 lxsession 2>/dev/null || true
pkill -9 lxpanel 2>/dev/null || true
pkill -9 openbox 2>/dev/null || true
pkill -f "Xorg :0" 2>/dev/null || true

if screen -ls | grep -q sunshine; then
  screen -ls | grep sunshine | awk '{print $1}' | xargs -r -n 1 screen -S {} -X quit
fi

echo "[+] All related processes killed."

# ===== 2. Install Sunshine =====
if ! command -v sunshine &>/dev/null; then
  wget -O /tmp/sunshine.deb \
  https://github.com/LizardByte/Sunshine/releases/download/v0.23.1/sunshine-ubuntu-22.04-amd64.deb
  sudo apt install -y /tmp/sunshine.deb
  rm /tmp/sunshine.deb
fi

sudo ufw allow ssh
sudo ufw allow 47984/tcp
sudo ufw allow 47989/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47990/tcp
sudo ufw allow 47998:48002/udp
sudo ufw --force enable

# ===== 3. Install Cloudflared =====
if ! command -v cloudflared &>/dev/null; then
  wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo apt install -y ./cloudflared-linux-amd64.deb
  rm cloudflared-linux-amd64.deb
fi

# ===== 4. Configure Dummy X =====
sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/xorg.conf.dummy >/dev/null <<EOF
Section "Device"
  Identifier "DummyDevice"
  Driver "dummy"
  VideoRam 256000
EndSection
Section "Monitor"
  Identifier "DummyMonitor"
  HorizSync 28.0-80.0
  VertRefresh 48.0-75.0
EndSection
Section "Screen"
  Identifier "DummyScreen"
  Device "DummyDevice"
  Monitor "DummyMonitor"
  DefaultDepth 24
  SubSection "Display"
    Depth 24
    Modes "1920x1080"
  EndSubSection
EndSection
EOF

# ===== 5. Start X + LXDE =====
sudo Xorg :0 -configdir /etc/X11/xorg.conf.d vt7 &
sleep 5
export DISPLAY=:0
lxsession &
sleep 5

# ===== 6. Start Sunshine =====
screen -dmS sunshine bash -c 'DISPLAY=:0 sunshine'
screen -dmS cloudflared bash -c 'cloudflared tunnel --no-tls-verify --url https://localhost:47990 > /tmp/cloudflared.log 2>&1'
sleep 5

TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)
echo "Tunnel URL: $TUNNEL_URL"

# ==================================================
# ===== 7. INSTALL CHROME + UI.VISION + 20 PROFILES
# ==================================================

echo "[+] Installing Google Chrome..."
if ! command -v google-chrome &>/dev/null; then
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
  sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
  sudo apt update
  sudo apt install -y google-chrome-stable
fi

BASE_DIR="$HOME/chrome-profiles"
EXT_DIR="$HOME/uivision_ext"
mkdir -p "$BASE_DIR" "$EXT_DIR"

echo "[+] Downloading UI.Vision extension..."
wget -O "$EXT_DIR/uivision.crx" \
"https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120.0&acceptformat=crx2,crx3&x=id%3Dgcbalfbdmfieckjlnblleoemohcganoc%26uc"

cd "$EXT_DIR"
unzip -o uivision.crx >/dev/null 2>&1 || true

echo "[+] Launching 20 Chrome profiles with UI.Vision..."

for i in $(seq 1 20); do
  PROFILE="$BASE_DIR/profile_$i"
  mkdir -p "$PROFILE"

  google-chrome \
    --user-data-dir="$PROFILE" \
    --load-extension="$EXT_DIR" \
    --no-first-run \
    --disable-infobars \
    --start-maximized &

  sleep 2
done

echo -e "${GREEN}✅ DONE: LXDE + Sunshine + Chrome + UI.Vision + 20 Profiles READY${RESET}"
