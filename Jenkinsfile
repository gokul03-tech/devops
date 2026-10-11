pipeline {
    agent any

    triggers {
        githubPush()
        pollSCM('H/2 * * * *')
    }

    parameters {
        string(name: 'VM_HOST', defaultValue: '', description: 'Public IP or DNS name used for HTTP verification and SSH by default.')
        string(name: 'VM_USER', defaultValue: 'azureuser', description: 'SSH login name for the Azure VM.')
        string(name: 'VM_SSH_HOST', defaultValue: '', description: 'Optional SSH hostname override; leave blank to use VM_HOST.')
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Backend Build & Test') {
            steps {
                dir('backend') {
                    sh '''
                        python3 -m venv .venv
                        . .venv/bin/activate
                        pip install --disable-pip-version-check -r requirements.txt
                        pytest -q
                    '''
                }
            }
        }

        stage('Frontend Build & Test') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run test -- --run'
                    sh 'npm run build'
                }
            }
        }

        stage('Package') {
            steps {
                sh 'tar -czf peerlearn-release.tar.gz backend/app.py backend/matching.py backend/requirements.txt backend/seed.py frontend/dist deploy'
                archiveArtifacts artifacts: 'peerlearn-release.tar.gz', fingerprint: true
            }
        }

        stage('Deploy') {
            when {
                expression {
                    env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' || env.GIT_BRANCH == 'origin/main'
                }
            }
            steps {
                script {
                    if (!params.VM_HOST?.trim() || !params.VM_USER?.trim()) {
                        error('Set VM_HOST and VM_USER in the Jenkins job parameters before deployment.')
                    }
                    if (!(params.VM_HOST ==~ /^[A-Za-z0-9.-]+$/) || !(params.VM_USER ==~ /^[A-Za-z_][A-Za-z0-9_-]*$/)) {
                        error('VM_HOST must be a host name or IPv4 address, and VM_USER must be a valid Linux login name.')
                    }
                    if (params.VM_SSH_HOST?.trim() && !(params.VM_SSH_HOST ==~ /^[A-Za-z0-9.-]+$/)) {
                        error('VM_SSH_HOST must be a host name or IPv4 address.')
                    }
                }
                sshagent(credentials: ['azure-vm-ssh']) {
                    sh '''
                        set -euo pipefail
                        SSH_HOST="${VM_SSH_HOST:-}"
                        if [ -z "$SSH_HOST" ]; then SSH_HOST="$VM_HOST"; fi
                        REMOTE="${VM_USER}@${SSH_HOST}"
                        REMOTE_ARCHIVE="/tmp/peerlearn-${BUILD_NUMBER}.tar.gz"
                        REMOTE_DIR="/tmp/peerlearn-release-${BUILD_NUMBER}"
                        mkdir -p "$HOME/.ssh"
                        chmod 700 "$HOME/.ssh"
                        touch "$HOME/.ssh/known_hosts"
                        chmod 600 "$HOME/.ssh/known_hosts"
                        if ! ssh-keygen -F "$SSH_HOST" -f "$HOME/.ssh/known_hosts" >/dev/null; then
                            ssh-keyscan -H "$SSH_HOST" >> "$HOME/.ssh/known_hosts" 2>/dev/null
                        fi
                        ssh-keygen -F "$SSH_HOST" -f "$HOME/.ssh/known_hosts" >/dev/null
                        SSH_OPTS="-o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts"
                        scp $SSH_OPTS peerlearn-release.tar.gz "$REMOTE:$REMOTE_ARCHIVE"
                        ssh $SSH_OPTS "$REMOTE" "mkdir -p '$REMOTE_DIR' && tar -xzf '$REMOTE_ARCHIVE' -C '$REMOTE_DIR' && sudo bash '$REMOTE_DIR/deploy/deploy.sh' '$REMOTE_DIR' && rm -rf '$REMOTE_DIR' '$REMOTE_ARCHIVE'"
                    '''
                }
            }
        }

        stage('Verify') {
            when {
                expression {
                    env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' || env.GIT_BRANCH == 'origin/main'
                }
            }
            steps {
                sh '''
                    set -euo pipefail
                    URL="http://${VM_HOST}/api/health"
                    for attempt in $(seq 1 12); do
                      if curl --fail --silent --show-error "$URL" | grep -q '"status":"ok"'; then
                        echo "PeerLearn health check passed at $URL"
                        exit 0
                      fi
                      sleep 5
                    done
                    echo "PeerLearn health check failed at $URL" >&2
                    exit 1
                '''
            }
        }
    }

    post {
        success { echo 'PeerLearn pipeline stages completed successfully.' }
        failure { echo 'PeerLearn CI/CD failed. Review the stage logs before retrying.' }
        always { cleanWs() }
    }
}
