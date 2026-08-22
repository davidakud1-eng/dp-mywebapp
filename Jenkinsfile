pipeline {
    agent { label 'build-agent' }

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
                    trivy image \
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
        }
    }
}