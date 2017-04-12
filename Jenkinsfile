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
            sh 'sudo ls -al'
            error 'Can\'t sudo.'
            
          },
          "user-pwd": {
            sh 'pwd'
            mail(subject: 'test-jenkins', body: 'This is a test from Jenkins', to: 'jacobfo@gmail.com')
            
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