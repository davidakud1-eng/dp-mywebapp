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

        stage('Verify Docker Environment') {
            steps {
                sh '''
                    echo "=== Docker Environment ==="
                    whoami
                    id
                    docker --version
                    docker info --format 'Docker Engine: {{.ServerVersion}}'
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