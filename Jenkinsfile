pipeline {
  agent any
  stages {
    stage('notify-start') {
      steps {
        echo 'The job is going to start!'
      }
    }
    stage('verify-start') {
      steps {
        input(message: 'Do you want to start the job?', id: 'begin', ok: 'start')
      }
    }
    stage('error') {
      steps {
        parallel(
          "sudo-list": {
            sh 'ls -al'
            
          },
          "user-pwd": {
            sh 'pwd'
            
          }
        )
      }
    }
    stage('notify-complete') {
      steps {
        sh 'echo \'job finished\''
      }
    }
  }
}