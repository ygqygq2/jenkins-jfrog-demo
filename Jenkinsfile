import jenkins.model.*

// 定义部署的 ssh server 的跳转 IP 和用户
def serverList= ["10.111.3.56": "root"]

pipeline {
  options {
    // 流水线超时设置
    timeout(time: 5, unit: 'HOURS')
    //保持构建的最大个数
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  agent none

  environment {
    // 全局环境变量
    SERVER_SSHKEY_ID = 'server-ssh-key'
    GIT_SSHKEY_ID = 'jenkins-git-ssh-key'
  }

  parameters {
    listGitBranches branchFilter: 'refs/heads/(.*)', defaultValue: '', credentialsId: 'jenkins-git-ssh-key',
      description: '部署分支/tag', listSize: '10', name: 'DEPLOY_BRANCH',
      quickFilterEnabled: true, selectedValue: 'DEFAULT',
      sortMode: 'NONE', tagFilter: '*', type: 'PT_BRANCH_TAG',
      remoteURL: 'git@github.com:jenkins-docs/simple-java-maven-app.git'
    string(defaultValue: '/tmp', description: '部署的目录',
      name: 'DEPLOY_DIR', trim: true)
    string(defaultValue: 'git@github.com:jenkins-docs/simple-java-maven-app.git', description: '部署的 git 仓库地址',
      name: 'DEPLOY_GIT_URL', trim: true)
  }

  stages {
    stage('获取 APP Info') {
      steps {
        script {
          env.APP_NAME = env.JOB_NAME.split('_')[-1];
          env.ENV_TAG = env.JOB_NAME.split('_')[0];
          env.PRODUCT_NAME = env.JOB_NAME.split('_')[1];
          env.PACKAGE_NAME = "${env.APP_NAME}-${env.DEPLOY_BRANCH}-${env.BUILD_NUMBER}.tar.gz"
          env.REPO_PATH = "generic-local/${env.PRODUCT_NAME}/${env.APP_NAME}/"
        }
      }
    }

    stage('下载代码') {
      agent {
        label "master"
      }
      steps {
        echo '################### Clone ###################'
        dir("code") {
          checkout scmGit(
            branches: [[name: "${env.DEPLOY_BRANCH}"]],
            userRemoteConfigs: [[url: "${env.DEPLOY_GIT_URL}", credentialsId: "${env.GIT_SSHKEY_ID}"]]
          )
        }
      }
    }

    stage('打包') {
      agent {
        docker {
          image 'maven:3.9.0-eclipse-temurin-11'
          args "-v /caches/maven:/root/.m2 -u root:root"
        }
        // dockerfile {
        //   dir 'code'
        //   additionalBuildArgs  '--build-arg version=1.0.2'
        // }
      }
      tools {
        jfrog 'jfrog-cli'
      }
      steps {
        echo '################### Package and Push ###################'
        sh '''#!/bin/sh -e
          cp -f conf/settings.xml /usr/share/maven/conf/settings.xml
          cd code
          mvn -B install --file pom.xml
          tar -zcvf ${PACKAGE_NAME} target/*.jar
          jf rt upload ${PACKAGE_NAME} ${REPO_PATH}
          jf rt build-publish
          sleep 600
        '''
      }
    }

    stage('部署') {
      steps {
        echo '################### Deploy ###################'
        script {
          serverList.each { ip, sshuser ->
            echo "#### 部署到 $ip ####"
            def remote = [:]
            remote.name = ip
            remote.user = sshuser
            remote.host = ip
            remote.allowAnyHosts = true

            withCredentials([sshUserPrivateKey(credentialsId: env.SERVER_SSHKEY_ID, usernameVariable: 'userName')]) {
              // remote.user = userName
              sshPut remote: remote, from: '${REPO_PATH}/${PACKAGE_NAME}', into: '/tmp/'
              sshCommand remote: remote, command: "tar -zxvf ${REPO_PATH}/${PACKAGE_NAME} -C ${DEPLOY_DIR}"

              // sshCommand remote: remote, command:
              //     "sed -i 's@dev/${env.APP_NAME}:\\(.*\\)@dev/${env.APP_NAME}:${env.NEW_TAG}@' /data/docker/docker-compose.yml"
              // sshCommand remote: remote, command: "sudo docker-compose -f /data/docker/docker-compose.yml up ${env.APP_NAME} -d || true"
            }
          }
        }
      }
    }
  }

  post {
    always {
      script{
        currentBuild.description = "Deploy: ${env.DEPLOY_BRANCH}"
      }
    }
  }
}
