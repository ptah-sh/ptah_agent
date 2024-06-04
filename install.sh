#!/usr/bin/env bash

set -e

# Header generated with http://www.kammerl.de/ascii/AsciiSignature.php
# Selected font - starwars

cat << EOF

.______   .___________.    ___       __    __           _______. __    __
|   _  \  |           |   /   \     |  |  |  |         /       ||  |  |  |
|  |_)  | \`---|  |----\`  /  ^  \    |  |__|  |        |   (----\`|  |__|  |
|   ___/      |  |      /  /_\  \   |   __   |         \   \    |   __   |
|  |          |  |     /  _____  \  |  |  |  |  __ .----)   |   |  |  |  |
| _|          |__|    /__/     \__\ |__|  |__| (__)|_______/    |__|  |__|

EOF


if [ "$(whoami)" != "root" ]; then
    echo "ERROR: You should be root to run this script."
    exit 1
fi

OS_NAME=$(cat /etc/os-release | grep "^ID=" | cut -d= -f2)

case "$OS_NAME" in
    ubuntu)
        echo "Installing ptah.sh agent for Ubuntu..."

        PKG_UPDATE_REGISTRIES="apt-get update"
        PKG_INSTALL="apt-get install -yq"

        export DEBIAN_FRONTEND=noninteractive
        ;;
    *)
        echo "Unsupported OS: $OS_NAME"
        echo "We currently support only Ubuntu."
        exit 1
        ;;
esac


ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        echo "We currently support only x86_64."
        exit 1
        ;;
esac

docker=$(which docker 2>/dev/null || true)
if [ ! -z "$docker" ]; then
    # TODO: ask to remove?
    # https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script

    echo "Existing Docker found. We currently not support existing Docker installations. Please remove it and try again."

    echo "To remove a legacy installation, please run:"
    echo ""
    echo "    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y \$pkg; done"
    echo ""

    echo "To remove existing installation, please run:"
    echo ""
    echo "    for pkg in docker-ce docker-ce-cli containerd.io; do sudo apt-get remove -y \$pkg; done"
    echo ""

    exit 1
fi

USER="ptah"
GROUP="ptah"

# No worries, this is a token from localhost
# TODO: extract PTAH_TOKEN and PTAH_HOST from env variables
PTAH_TOKEN="SFMyNTY.g2gDYQ5uBgDhPHyijwFiAAFRgA.dr91FMV57KWmbWVR99jCMSFgMCj7H6-q8cy6b8pE3Kc"
PTAH_HOST="ws://ptah.a.pinggy.link:22967/sockets/agent/websocket"

echo "User: $USER:$GROUP"

INSTALL_CORE=(
    sudo
    curl
    unzip
    ca-certificates
    iproute2
)

INSTALL_DOCKER=(
    docker-ce
    docker-ce-cli
    containerd.io
)

INSTALL_SYSTEM=(
    ${INSTALL_CORE[@]}
    ${INSTALL_DOCKER[@]}
)

echo "We will install into the system:"
for pkg in "${INSTALL_SYSTEM[@]}"; do
    echo "    - $pkg"
done

$PKG_UPDATE_REGISTRIES

$PKG_INSTALL ${INSTALL_CORE[*]}

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

$PKG_UPDATE_REGISTRIES

$PKG_INSTALL ${INSTALL_DOCKER[*]}

group_exists=$(sudo getent group "$GROUP" || true)
if [ -z "$group_exists" ]; then
    echo "Creating group: $GROUP"

    sudo groupadd "$GROUP"
fi

user_exists=$(sudo getent passwd "$USER" || true)
if [ -z "$user_exists" ]; then
    echo "Creating user: $USER"

    sudo useradd --create-home --no-user-group --gid "$GROUP" --groups docker --system "$USER"
fi

echo "Switching to user: $USER"

sudo -u "$USER" bash << EOF

set -e

echo "Running in user space as \$(whoami)"

cat << BASHRC > ~/.bashrc

# Configuration created by https://ptah.sh agent installer.
export XDG_RUNTIME_DIR="\$HOME/.cache/xdgr"

BASHRC

curl -L https://github.com/ptah-sh/ptah_agent/releases/latest/download/ptah_agent_linux_x86_64.tar.xz -o /tmp/ptah_agent_latest.tar.xz

mkdir -p \$HOME/ptah_agent/versions/0_seed

tar -xvJf /tmp/ptah_agent_latest.tar.xz -C \$HOME/ptah_agent/versions/0_seed

ln -sf \$HOME/ptah_agent/versions/0_seed/ptah_agent/ \$HOME/ptah_agent/current/

EOF

echo "Installing ptah-agent systemd service..."

# TODO: add ExecStartPre and ExecStartPost to notify about agent restarts
cat <<EOF > /etc/systemd/system/ptah-agent.service
[Unit]
Description=Ptah.sh Agent
Documentation=https://ptah.sh
After=network.target

[Service]
User=$USER
Group=$GROUP
Environment=PTAH_HOME=/home/$USER
Environment=PTAH_TOKEN=$PTAH_TOKEN
Environment=PTAH_HOST=$PTAH_HOST
Type=exec
ExecStart=/home/$USER/ptah_agent/current/bin/ptah_agent start
Restart=always
RestartSteps=5
RestartSec=5
RestartMaxDelaySec=30

[Install]
WantedBy=multi-user.target
EOF

if [ -z "$(which systemctl)" ]; then
    echo "Are you running in Docker?"
    echo "Exiting an installation script with success, because systemctl not found."
    echo "Please add the following command to your init system manually:"
    echo ""
    echo "    /home/$USER/ptah_agent/current/bin/ptah-agent start".
    echo ""

    exit 1
fi

echo "Reloading systemd..."

systemctl daemon-reload
systemctl enable ptah-agent
systemctl start ptah-agent

# TODO: ??? automatically check if the agent is actually running by looking at the logs/pid file

echo "Installation complete. Please check status on https://app.ptah.sh."
