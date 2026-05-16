def dockerBuildAndPush(String registry) {
    def targetRegistry = registry?.trim()
    if (!targetRegistry) {
        error 'Docker registry must be configured in Jenkins environment variables'
    }

    withEnv(["TARGET_DOCKER_REPO=${targetRegistry}"]) {
        withCredentials([usernamePassword(credentialsId: 'nexus-docker-creds',
            usernameVariable: 'NEXUS_USERNAME',
            passwordVariable: 'NEXUS_PASSWORD')]) {
            sh '''#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${TARGET_DOCKER_REPO}"
IMAGE_TAG="${REGISTRY}/${IMAGE_NAME}:${SHORT_GIT_COMMIT}"

export DOCKER_CONFIG="${WORKSPACE}/.docker-config"
rm -rf "${DOCKER_CONFIG}"
umask 077
mkdir -p "${DOCKER_CONFIG}"

cleanup() {
    docker logout "${REGISTRY}" >/dev/null 2>&1 || true
    rm -rf "${DOCKER_CONFIG}"
}
trap cleanup EXIT

DOCKER_BUILDKIT=1 docker build -t "${IMAGE_TAG}" .
printf '%s' "${NEXUS_PASSWORD}" | docker login "${REGISTRY}" --username "${NEXUS_USERNAME}" --password-stdin
docker push "${IMAGE_TAG}"
'''
        }
    }
}

pipeline {
    agent { label 'docker-agent' }

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME = 'spring-petclinic'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_GIT_COMMIT = sh(
                        script: '''#!/usr/bin/env bash
set -euo pipefail
git rev-parse --short=8 HEAD
''',
                        returnStdout: true
                    ).trim()

                    echo "Building ${env.BRANCH_NAME} at ${env.SHORT_GIT_COMMIT}"
                }
            }
        }

        stage('Checkstyle') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail
./mvnw -B checkstyle:checkstyle
'''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'target/reports/checkstyle.html,target/site/checkstyle*.html,target/site/checkstyle*.xml,target/checkstyle*.xml,target/checkstyle-result.xml',
                        allowEmptyArchive: true,
                        fingerprint: true
                }
            }
        }

        stage('Test') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail
./mvnw -B test
'''
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml',
                        allowEmptyResults: true
                }
            }
        }

        stage('Build Application') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail
./mvnw -B -DskipTests package
'''
            }
        }

        stage('Docker Build and Push to MR Nexus') {
            when {
                not {
                    branch 'main'
                }
            }
            steps {
                script {
                    dockerBuildAndPush(env.MR_DOCKER_REPO)
                }
            }
        }

        stage('Docker Build and Push to Main Nexus') {
            when {
                branch 'main'
            }
            steps {
                script {
                    dockerBuildAndPush(env.MAIN_DOCKER_REPO)
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
