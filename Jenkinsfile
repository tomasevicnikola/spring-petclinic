def dockerBuildAndPush(String registry, boolean pushLatest = false) {
    def targetRegistry = registry?.trim()
    if (!targetRegistry) {
        error 'Docker registry must be configured in Jenkins environment variables'
    }

    withEnv(["TARGET_DOCKER_REPO=${targetRegistry}", "PUSH_LATEST_TAG=${pushLatest}"]) {
        withCredentials([usernamePassword(credentialsId: 'nexus-docker-creds',
            usernameVariable: 'NEXUS_USERNAME',
            passwordVariable: 'NEXUS_PASSWORD')]) {
            sh '''#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${TARGET_DOCKER_REPO}"
IMAGE_TAG="${REGISTRY}/${IMAGE_NAME}:${SHORT_GIT_COMMIT}"
LATEST_TAG="${REGISTRY}/${IMAGE_NAME}:latest"

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
if [ "${PUSH_LATEST_TAG}" = "true" ]; then
    docker tag "${IMAGE_TAG}" "${LATEST_TAG}"
fi

printf '%s' "${NEXUS_PASSWORD}" | docker login "${REGISTRY}" --username "${NEXUS_USERNAME}" --password-stdin
docker push "${IMAGE_TAG}"
if [ "${PUSH_LATEST_TAG}" = "true" ]; then
    docker push "${LATEST_TAG}"
fi
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
./mvnw -B -DskipTests clean package

jar_list="$(mktemp)"
trap 'rm -f "${jar_list}"' EXIT

find target -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort > "${jar_list}"
jar_count="$(wc -l < "${jar_list}" | tr -d ' ')"
if [ "${jar_count}" -ne 1 ]; then
    echo "Expected exactly one application JAR in target, found ${jar_count}" >&2
    cat "${jar_list}" >&2
    exit 1
fi

application_jar="$(sed -n '1p' "${jar_list}")"
if [ "${application_jar}" != "target/app.jar" ]; then
    mv "${application_jar}" target/app.jar
fi

test -s target/app.jar
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
                    dockerBuildAndPush(env.MAIN_DOCKER_REPO, true)
                }
            }
        }
    }

    post {
        failure {
            catchError(buildResult: 'FAILURE',
                message: 'Failure notification email could not be sent') {
                emailext recipientProviders: [developers(), culprits(), requestor()],
                    subject: "Failed Pipeline: ${currentBuild.fullDisplayName}",
                    mimeType: 'text/plain',
                    body: """Pipeline failed.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Branch: ${env.BRANCH_NAME}
Commit: ${env.SHORT_GIT_COMMIT ?: 'unknown'}
Build URL: ${env.BUILD_URL}
"""
            }
        }
        always {
            cleanWs()
        }
    }
}
