pipeline {
    agent { label 'build-agent' }

    stages {
        stage('Build and Test') {
            steps {
                sh 'mvn clean verify'
            }
        }
    }

    post {
        always {
            junit 'target/surefire-reports/*.xml'
        }
    }
}