pipeline {
    agent any

    triggers {
        githubPush()
        pollSCM('H/2 * * * *')
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
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
                        pytest -q --cov=matching --cov=app --cov-fail-under=80
                    '''
                }
            }
        }
        stage('Frontend Build & Test') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm test -- --reporter=dot'
                    sh 'npm run build'
                }
            }
        }
        stage('Package') {
            steps {
                sh 'tar -czf peerlearn-release.tar.gz backend/app.py backend/matching.py backend/requirements.txt backend/seed.py frontend/dist deploy/deploy.sh'
                archiveArtifacts artifacts: 'peerlearn-release.tar.gz', fingerprint: true
            }
        }
        stage('Deploy') {
            steps {
                script {
                    if (!env.VM_IP?.trim() || !env.VM_HOST?.trim() || !env.VM_USER?.trim()) {
                        error('Set VM_IP, VM_HOST and VM_USER in Jenkins global or job environment properties before deployment.')
                    }
                    if (!(env.VM_IP ==~ /^[0-9.]+$/) || !(env.VM_HOST ==~ /^[A-Za-z0-9.-]+$/) || !(env.VM_USER ==~ /^[A-Za-z_][A-Za-z0-9_-]*$/)) {
                        error('VM_IP must be IPv4, VM_HOST must be a host name or IP, and VM_USER must be a valid Linux login name.')
                    }
                }
                sshagent(credentials: ['azure-vm-ssh']) {
                    sh '''
                        REMOTE="${VM_USER}@${VM_HOST}"
                        ssh -o StrictHostKeyChecking=accept-new "$REMOTE" 'mkdir -p /tmp/peerlearn-release'
                        scp -o StrictHostKeyChecking=accept-new peerlearn-release.tar.gz "$REMOTE:/tmp/peerlearn-release.tar.gz"
                        ssh -o StrictHostKeyChecking=accept-new "$REMOTE" \
                          'rm -rf /tmp/peerlearn-release && mkdir -p /tmp/peerlearn-release && tar -xzf /tmp/peerlearn-release.tar.gz -C /tmp/peerlearn-release && sudo bash /tmp/peerlearn-release/deploy/deploy.sh /tmp/peerlearn-release'
                    '''
                }
            }
        }
        stage('Verify') {
            steps {
                sh '''
                    URL="http://${VM_IP}/api/health"
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
        success { echo 'PeerLearn pipeline succeeded: tests passed and deployment is healthy.' }
        failure { echo 'PeerLearn pipeline failed. Review the stage logs before retrying.' }
        always { deleteDir() }
    }
}
