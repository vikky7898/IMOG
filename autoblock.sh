read -p "Enter your HF token: " HF_TOKEN; echo && \
mkdir -p ~/blockassist && \
cat <<EOF > ~/blockassist/blockassist_auto.sh
#!/bin/bash

if [ -z "\$TMUX" ]; then
  echo "❌ Please run this script inside tmux"
  exit 1
fi

TARGET_PANE="\$(tmux display-message -p '#S:#I.#P')"
HF_TOKEN="$HF_TOKEN"

(
  tmux display-message "AUTO → pane \$TARGET_PANE"

  sleep 5
  tmux send-keys -t "\$TARGET_PANE" "\$HF_TOKEN" Enter

  sleep 120
  tmux send-keys -t "\$TARGET_PANE" Enter

  sleep 240
  for i in \$(seq 1 20); do
    tmux display-message "AUTO ENTER #\$i"
    tmux send-keys -t "\$TARGET_PANE" Enter
    sleep 5
  done
) &

cd ~/blockassist
export DISPLAY=:0
pyenv exec python run.py
EOF

chmod +x ~/blockassist/blockassist_auto.sh
echo "🎯 Script ready! Run inside tmux:"
echo "cd ~/blockassist && ./blockassist_auto.sh"
