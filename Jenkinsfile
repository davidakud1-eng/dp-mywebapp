pipeline {
    agent { label 'build-agent' }

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {

        // ================================================================
        // EKS Runtime Control
        //
        // Disabled by default so normal CI builds can complete without
        // requiring the ephemeral DP EKS runtime to exist.
        //
        // When enabled, the application is deployed to EKS from the
        // Platform Ops Jenkins agent.
        // ================================================================

        booleanParam(
            name: 'EKS_RUNTIME_ENABLED',
            defaultValue: false,
            description: 'Deploy DP MyWebApp to the EKS runtime.'
        )
    }

    environment {

        // ================================================================
        // Artifact and Container Registry Configuration
        // ================================================================

        ARTIFACTORY_URL = 'http://10.0.43.83:8082/artifactory'
        DOCKERHUB_REPOSITORY = 'kingdayve/dp-mywebapp'

        // ================================================================
        // EKS Deployment Configuration
        // ================================================================

        EKS_CLUSTER_NAME = 'dp-eks-cluster'
        EKS_REGION = 'us-east-2'
        EKS_NAMESPACE = 'dp-app'
        HELM_RELEASE_NAME = 'dp-mywebapp'
    }

    stages {

        // ==================================================================
        // Compile and Test
        // ==================================================================

        stage('Compile and Test') {
            steps {
                sh 'mvn clean test'
            }
        }

        // ==================================================================
        // Snyk Software Composition Analysis
        // ==================================================================

        stage('Snyk SCA Scan') {
            steps {
                snykSecurity(
                    organisation: 'davidakud1-eng',
                    projectName: 'dp-mywebapp',
                    severity: 'high',
                    snykInstallation: 'DP-Snyk',
                    snykTokenId: 'snyk-token'
                )
            }
        }

        // ==================================================================
        // Package and Verify
        //
        // Maven verify also produces the JaCoCo coverage data used by the
        // subsequent SonarCloud analysis.
        // ==================================================================

        stage('Package and Verify') {
            steps {
                sh 'mvn verify -DskipTests'
            }
        }

        // ==================================================================
        // Verify Executable JAR
        // ==================================================================

        stage('Verify Executable JAR') {
            steps {
                sh '''
                    timeout 30s java -jar target/dp-mywebapp-1.0.0-SNAPSHOT.jar > /tmp/dp-mywebapp.log 2>&1 &
                    APP_PID=$!

                    for i in $(seq 1 20); do
                        if curl --fail --silent http://localhost:8080/actuator/health; then
                            kill "$APP_PID" 2>/dev/null || true
                            wait "$APP_PID" 2>/dev/null || true
                            exit 0
                        fi

                        sleep 1
                    done

                    cat /tmp/dp-mywebapp.log
                    kill "$APP_PID" 2>/dev/null || true
                    wait "$APP_PID" 2>/dev/null || true
                    exit 1
                '''
            }
        }

        // ==================================================================
        // SonarCloud Static Analysis
        // ==================================================================

        stage('SonarCloud Analysis') {
            steps {
                withSonarQubeEnv('DP-SonarCloud') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        // ==================================================================
        // Publish Maven Artifact to Artifactory
        // ==================================================================

        stage('Publish Artifact to Artifactory') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'artifactory-token',
                        variable: 'ARTIFACTORY_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        umask 077

                        cat > "$WORKSPACE/dp-maven-settings.xml" <<EOF_SETTINGS
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">

    <servers>
        <server>
            <id>dp-artifactory-release</id>
            <username>dp-jenkins</username>
            <password>${ARTIFACTORY_TOKEN}</password>
        </server>

        <server>
            <id>dp-artifactory-snapshot</id>
            <username>dp-jenkins</username>
            <password>${ARTIFACTORY_TOKEN}</password>
        </server>
    </servers>

</settings>
EOF_SETTINGS

                        mvn \
                            --settings "$WORKSPACE/dp-maven-settings.xml" \
                            deploy \
                            -DskipTests
                    '''
                }
            }
        }

        // ==================================================================
        // Docker Build
        // ==================================================================

        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                        --tag dp-mywebapp:${BUILD_NUMBER} \
                        --tag dp-mywebapp:latest \
                        .
                '''
            }
        }

        // ==================================================================
        // Trivy Container Image Scan
        // ==================================================================

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    mkdir -p "$HOME/trivy-tmp"

                    TMPDIR="$HOME/trivy-tmp" trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --ignore-unfixed \
                        dp-mywebapp:${BUILD_NUMBER}
                '''
            }
        }

        // ==================================================================
        // Publish Container Image to Docker Hub
        // ==================================================================

        stage('Publish Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "$DOCKERHUB_TOKEN" | \
                            docker login \
                                --username "$DOCKERHUB_USERNAME" \
                                --password-stdin

                        docker tag \
                            dp-mywebapp:${BUILD_NUMBER} \
                            ${DOCKERHUB_REPOSITORY}:${BUILD_NUMBER}

                        docker tag \
                            dp-mywebapp:${BUILD_NUMBER} \
                            ${DOCKERHUB_REPOSITORY}:latest

                        docker push \
                            ${DOCKERHUB_REPOSITORY}:${BUILD_NUMBER}

                        docker push \
                            ${DOCKERHUB_REPOSITORY}:latest
                    '''
                }
            }
        }

        // ==================================================================
        // Deploy to EKS
        //
        // This stage runs only when EKS_RUNTIME_ENABLED=true.
        //
        // The CI stages above execute on the permanent Build Agent.
        //
        // EKS deployment switches execution to Platform Ops because that
        // Jenkins agent owns:
        //
        //   - AWS IAM identity
        //   - EKS cluster access
        //   - AWS CLI
        //   - kubectl
        //   - Helm
        //
        // No long-lived AWS access keys are required by this pipeline.
        // ==================================================================

        stage('Deploy to EKS') {

            when {
                expression {
                    return params.EKS_RUNTIME_ENABLED
                }
            }

            agent {
                label 'platform-ops'
            }

            steps {

                // The stage runs on a different Jenkins agent, so the
                // repository is checked out into the Platform Ops workspace.

                checkout scm

                sh '''
                    set -e

                    echo "=== VERIFY PLATFORM OPS TOOLING ==="
                    aws --version
                    kubectl version --client
                    helm version

                    echo
                    echo "=== VERIFY AWS EXECUTION IDENTITY ==="
                    aws sts get-caller-identity

                    echo
                    echo "=== CONFIGURE EKS ACCESS ==="
                    aws eks update-kubeconfig \
                        --region "$EKS_REGION" \
                        --name "$EKS_CLUSTER_NAME"

                    echo
                    echo "=== VERIFY EKS CONNECTIVITY ==="
                    kubectl get nodes -o wide

                    echo
                    echo "=== VALIDATE HELM CHART ==="
                    helm lint helm/dp-mywebapp

                    echo
                    echo "=== DEPLOY DP MYWEBAPP ==="
                    helm upgrade --install \
                        "$HELM_RELEASE_NAME" \
                        helm/dp-mywebapp \
                        --namespace "$EKS_NAMESPACE" \
                        --create-namespace \
                        --set image.repository="$DOCKERHUB_REPOSITORY" \
                        --set image.tag="$BUILD_NUMBER" \
                        --wait \
                        --timeout 5m

                    echo
                    echo "=== VERIFY DEPLOYMENT ==="
                    kubectl rollout status \
                        deployment/dp-mywebapp \
                        --namespace "$EKS_NAMESPACE" \
                        --timeout=5m

                    echo
                    echo "=== DP APPLICATION RESOURCES ==="
                    kubectl get \
                        deployments,pods,services,ingress,hpa,pdb \
                        --namespace "$EKS_NAMESPACE"
                '''
            }
        }
    }

    post {

        // ==================================================================
        // Cleanup
        // ==================================================================

        always {
            sh '''
                rm -f "$WORKSPACE/dp-maven-settings.xml"
                docker logout || true
            '''
        }

        // ==================================================================
        // Pipeline Result
        // ==================================================================

        success {
            echo 'DP MyWebApp pipeline completed successfully.'
        }

        failure {
            echo 'DP MyWebApp pipeline failed.'
        }
    }
}