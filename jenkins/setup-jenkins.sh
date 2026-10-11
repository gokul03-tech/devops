#!/usr/bin/env bash
# Install Jenkins and the build tools on Ubuntu 22.04. Run as root or with sudo.
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash setup-jenkins.sh" >&2; exit 1; fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl fontconfig git python3 python3-venv python3-pip gnupg wget openjdk-17-jre-headless
install -d -m 0755 /etc/apt/keyrings
wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor --yes -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo "$VERSION_CODENAME") main" > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y temurin-21-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins

# Install Node.js 20 for the Vite build.
if ! node --version 2>/dev/null | grep -q '^v20\.'; then
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  chmod a+r /etc/apt/keyrings/nodesource.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y nodejs
fi

# Recent Jenkins LTS releases need Java 21 to run; Java 17 remains installed for build tools.
install -d -m 0755 /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/java.conf <<'EOF'
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/temurin-21-jre-amd64"
Environment="JENKINS_JAVA_CMD=/usr/lib/jvm/temurin-21-jre-amd64/bin/java"
EOF
systemctl daemon-reload
systemctl enable --now jenkins
jenkins-plugin-cli --plugins git github workflow-aggregator ssh-agent credentials-binding ws-cleanup
systemctl restart jenkins
echo "Jenkins installed. Required plugins: Git, GitHub, Pipeline, SSH Agent, Credentials Binding."
echo "Unlock key: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "Install plugins after completing the first-run wizard, then restart Jenkins if prompted."
