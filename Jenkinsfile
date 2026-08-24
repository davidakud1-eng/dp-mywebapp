pipeline {
    agent { label 'build-agent' }

    environment {
        ARTIFACTORY_URL = 'http://10.0.43.83:8082/artifactory'
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
                sh 'java -jar target/dp-mywebapp-1.0.0-SNAPSHOT.jar'
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
                        cat > "$WORKSPACE/dp-maven-settings.xml" <<EOF
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
EOF

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
    }

    post {
        always {
            junit 'target/surefire-reports/*.xml'

            recordCoverage(
                tools: [[
                    parser: 'JACOCO',
                    pattern: 'target/site/jacoco/jacoco.xml'
                ]]
            )

            sh 'rm -f "$WORKSPACE/dp-maven-settings.xml"'
        }
    }
}