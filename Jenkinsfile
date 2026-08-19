pipeline {
    agent { label 'build-agent' }

    stages {
        stage('Build and Test') {
            steps {
                sh 'mvn clean verify'
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