cat > setup.sh <<'EOF'
#!/bin/bash
set -e

echo "==============================================="
echo " XFCE + noVNC + CLOUDFLARE (BROWSER DESKTOP)"
echo "==============================================="

echo "[+] Cleaning old processes..."
pkill -9 cloudflared 2>/dev/null || true
pkill -9 x11vnc 2>/dev/null || true
pkill -9 websockify 2>/dev/null || true
pkill -9 novnc 2>/dev/null || true
pkill -9 xfce4-session 2>/dev/null || true
pkill -9 xfwm4 2>/dev/null || true
pkill -9 Xorg 2>/dev/null || true
screen -wipe || true
sleep 2

echo "[+] Installing packages..."
sudo apt update
sudo apt install -y \
  xfce4 xfce4-goodies \
  xserver-xorg-video-dummy \
  dbus-x11 \
  x11vnc \
  git python3 \
  curl wget unzip screen

if [ ! -d /opt/novnc ]; then
  echo "[+] Installing noVNC..."
  sudo git clone https://github.com/novnc/noVNC.git /opt/novnc
  sudo git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify
fi

sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/10-dummy.conf >/dev/null <<EOL
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
EOL

echo "[+] Starting Xorg..."
sudo Xorg :0 -configdir /etc/X11/xorg.conf.d vt7 &
sleep 5
export DISPLAY=:0

echo "[+] Starting XFCE..."
screen -dmS xfce bash -c '
  export DISPLAY=:0
  eval "$(dbus-launch --sh-syntax)"
  xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
  startxfce4
'
sleep 6

echo "[+] Starting x11vnc..."
screen -dmS vnc bash -c '
  x11vnc -display :0 -nopw -forever -shared -rfbport 5900
'
sleep 3

echo "[+] Starting noVNC on port 6080..."
screen -dmS novnc bash -c '
  cd /opt/novnc
  ./utils/novnc_proxy --vnc localhost:5900 --listen 0.0.0.0:6080
'
sleep 4

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[+] Installing Cloudflared..."
  wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo apt install -y ./cloudflared-linux-amd64.deb
  rm cloudflared-linux-amd64.deb
fi

echo "[+] Starting Cloudflare tunnel..."
cloudflared tunnel --url http://localhost:6080 > /tmp/cloudflared.log 2>&1 &
sleep 6

TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)

echo "==============================================="
if [ -n "$TUNNEL_URL" ]; then
  echo "🌍 BROWSER DESKTOP LINK:"
  echo "$TUNNEL_URL/vnc.html"
else
  echo "❌ Cloudflare link not found"
  echo "Check /tmp/cloudflared.log"
fi
echo "==============================================="

echo "✅ XFCE Desktop READY in Browser (noVNC)"
EOF
chmod +x setup.sh && ./setup.sh
