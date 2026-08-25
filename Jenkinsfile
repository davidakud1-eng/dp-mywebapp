pipeline {
    agent { label 'build-agent' }

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        booleanParam(
            name: 'EKS_RUNTIME_ENABLED',
            defaultValue: false,
            description: 'Deploy DP MyWebApp to the EKS runtime'
        )
    }

    environment {
        ARTIFACTORY_URL = 'http://10.0.43.83:8082/artifactory'
        DOCKERHUB_REPOSITORY = 'kingdayve/dp-mywebapp'

        EKS_CLUSTER_NAME = 'dp-eks-cluster'
        EKS_REGION = 'us-east-2'
        EKS_NAMESPACE = 'dp-app'
        HELM_RELEASE_NAME = 'dp-mywebapp'
    }

    stages {

        stage('Compile and Test') {
            steps {
                sh 'mvn clean test'
            }
        }

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

        stage('Package and Verify') {
            steps {
                sh 'mvn verify -DskipTests'
            }
        }

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

        stage('SonarCloud Analysis') {
            steps {
                withSonarQubeEnv('DP-SonarCloud') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Publish Artifact to Artifactory') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'artifactory-token',
                        variable: 'ARTIFACTORY_TOKEN'
                    )
                ]) {
                    sh '''
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
        // EKS Deployment
        //
        // Runs on Platform Ops because that agent owns:
        //   - AWS IAM identity
        //   - EKS access
        //   - kubectl
        //   - Helm
        //
        // Jenkins automatically checks out this repository into the
        // Platform Ops workspace when entering this stage.
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

                checkout scm

                sh '''
                    set -e

                    echo "=== VERIFY PLATFORM OPS TOOLING ==="
                    aws --version
                    kubectl version --client
                    helm version

                    echo "=== CONFIGURE EKS ACCESS ==="
                    aws eks update-kubeconfig \
                        --region "$EKS_REGION" \
                        --name "$EKS_CLUSTER_NAME"

                    echo "=== VERIFY EKS CONNECTIVITY ==="
                    kubectl get nodes

                    echo "=== VALIDATE HELM CHART ==="
                    helm lint helm/dp-mywebapp

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

                    echo "=== VERIFY DEPLOYMENT ==="
                    kubectl rollout status \
                        deployment/dp-mywebapp \
                        --namespace "$EKS_NAMESPACE" \
                        --timeout=5m

                    echo "=== DP APPLICATION RESOURCES ==="
                    kubectl get \
                        deployments,pods,services,ingress,hpa,pdb \
                        --namespace "$EKS_NAMESPACE"
                '''
            }
        }
    }

    post {
        always {
            sh '''
                rm -f "$WORKSPACE/dp-maven-settings.xml"
                docker logout || true
            '''
        }

        success {
            echo 'DP MyWebApp pipeline completed successfully.'
        }

        failure {
            echo 'DP MyWebApp pipeline failed.'
        }
    }
}
