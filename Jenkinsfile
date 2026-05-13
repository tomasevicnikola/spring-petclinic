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
        // Jenkins runs this pipeline inside an agent container, so Nexus is reached through the host.
        MAIN_DOCKER_REPO = 'host.docker.internal:8082'
        MR_DOCKER_REPO = 'host.docker.internal:8083'
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

                    def detectedBranch = env.CHANGE_BRANCH ?: env.BRANCH_NAME ?: env.GIT_BRANCH ?: sh(
                        script: '''#!/usr/bin/env bash
set -euo pipefail
git rev-parse --abbrev-ref HEAD
''',
                        returnStdout: true
                    ).trim()

                    detectedBranch = detectedBranch.replaceFirst('^origin/', '').replaceFirst('^refs/heads/', '')

                    env.BUILD_BRANCH = detectedBranch
                    env.IS_MAIN_BRANCH = detectedBranch == 'main' ? 'true' : 'false'

                    echo "Building ${env.BUILD_BRANCH} at ${env.SHORT_GIT_COMMIT}"
                }
            }
        }

        stage('Checkstyle') {
            when {
                expression { env.IS_MAIN_BRANCH != 'true' }
            }
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
            when {
                expression { env.IS_MAIN_BRANCH != 'true' }
            }
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
            when {
                expression { env.IS_MAIN_BRANCH != 'true' }
            }
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail
./mvnw -B -DskipTests package
'''
            }
        }

        stage('Docker Build and Push to MR Nexus') {
            when {
                expression { env.IS_MAIN_BRANCH != 'true' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-docker-creds',
                    usernameVariable: 'NEXUS_USERNAME',
                    passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${MR_DOCKER_REPO}/${IMAGE_NAME}:${SHORT_GIT_COMMIT}"
trap 'docker logout "${MR_DOCKER_REPO}" >/dev/null 2>&1 || true' EXIT

DOCKER_BUILDKIT=1 docker build -t "${IMAGE_TAG}" .
printf '%s' "${NEXUS_PASSWORD}" | docker login "${MR_DOCKER_REPO}" --username "${NEXUS_USERNAME}" --password-stdin
docker push "${IMAGE_TAG}"
'''
                }
            }
        }

        stage('Docker Build and Push to Main Nexus') {
            when {
                expression { env.IS_MAIN_BRANCH == 'true' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-docker-creds',
                    usernameVariable: 'NEXUS_USERNAME',
                    passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${MAIN_DOCKER_REPO}/${IMAGE_NAME}:${SHORT_GIT_COMMIT}"
trap 'docker logout "${MAIN_DOCKER_REPO}" >/dev/null 2>&1 || true' EXIT

DOCKER_BUILDKIT=1 docker build -t "${IMAGE_TAG}" .
printf '%s' "${NEXUS_PASSWORD}" | docker login "${MAIN_DOCKER_REPO}" --username "${NEXUS_USERNAME}" --password-stdin
docker push "${IMAGE_TAG}"
'''
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
