#!/bin/bash
set -euxo pipefail

LOG=/var/log/openagent-launch.log
exec > >(tee -a "$LOG") 2>&1

echo "Starting Lightsail bootstrap"

# 1. Prevent apt from hanging on interactive prompts during boot
export DEBIAN_FRONTEND=noninteractive

# 2. Extract configuration to the top
TARGET_USER="ubuntu"
REPO_URL="https://github.com/your-username/Personal-Agent-Homebase.git" # <-- REPLACE THIS URL

apt-get update -y
apt-get install -y git curl ca-certificates gnupg lsb-release make

# Install Docker
curl -fsSL https://get.docker.com | sh

# Create the target directory first
mkdir -p /opt/openagent

# 3. Safely scope user-dependent commands inside the user check
if id "$TARGET_USER" >/dev/null 2>&1; then
  usermod -aG docker "$TARGET_USER"
  
  # Use the variable instead of hardcoding 'ubuntu'
  chown -R "$TARGET_USER":"$TARGET_USER" /opt/openagent

  if [ ! -d /opt/openagent/Personal-Agent-Homebase ]; then
    # 4. Use double quotes so the $REPO_URL variable expands correctly
    su - "$TARGET_USER" -c "git clone $REPO_URL /opt/openagent/Personal-Agent-Homebase"
  fi
else
  echo "WARNING: User '$TARGET_USER' does not exist. Skipping user assignment and git clone."
fi

echo "Bootstrap complete"
echo "Log written to $LOG"