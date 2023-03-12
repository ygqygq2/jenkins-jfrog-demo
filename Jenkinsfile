import jenkins.model.*
import groovy.json.JsonSlurper

// 定义部署的 ssh server 的跳转 IP 和用户
def serverList= ["10.111.3.56": "root"]

pipeline {
  options {
    // 流水线超时设置
    timeout(time: 5, unit: 'HOURS')
    //保持构建的最大个数
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  agent {
    label "master"
  }

  environment {
    // 全局环境变量
    // 服务器 ssh key
    SERVER_SSHKEY_ID = 'server-ssh-key'
    // git sshkey
    GIT_SSHKEY_ID = 'jenkins-git-ssh-key'
    // docker login user
    DOCKER_CRE = credentials('jfrog-admin-user')
    // docker repository
    // docker virtual repository is "dev"
    DOCKER_REP = 'docker-local'
    // jfrog container registry
    DOCKER_URL = 'https://reg.k8snb.com'
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
    string(defaultValue: 'file', description: '部署的类型 file/docker',
      name: 'DEPLOY_TYPE', trim: true)
  }

  stages {
    stage('获取 APP Info') {
      steps {
        script {
          if (env.DEPLOY_BRANCH == '') {
            echo "必须选择分支或 TAG"
            currentBuild.result = 'ABORTED'
            sh "exit 1"
          }
          env.APP_NAME = env.JOB_NAME.split('_')[-1];
          env.ENV_TAG = env.JOB_NAME.split('_')[0];
          env.PRODUCT_NAME = env.JOB_NAME.split('_')[1];
          env.PACKAGE_NAME = "${env.APP_NAME}-${env.DEPLOY_BRANCH}-${env.BUILD_NUMBER}.tar.gz"
          env.REPO_PATH = "generic-local/${env.PRODUCT_NAME}/${env.APP_NAME}"
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
          script {
            // 因为分支/ TAG 内可能含特殊字符，所以先下载代码从 git 中获取
            env.TMP_TAG = sh(script: '#!/bin/sh -e\n git rev-parse --abbrev-ref HEAD|sed "s/[^[:alnum:]._-]/-/g"',
              returnStdout: true).trim()
          }
        }
      }
    }

    stage('获取容器 TAG') {
      when {
        environment name: 'DEPLOY_TYPE', value: 'docker'
      }
      steps {
        script {
          echo '################### 获取 Tag 开始 ###################'
          // 初始页
          def page = 0
          // 一次查询的数量
          def n = 30
          def allTags = []
          def LATEST_TAG = ''
          def JSON = sh(script: '#!/bin/sh -e\n curl -s --connect-timeout 60 -u ${DOCKER_CRE_USR}:${DOCKER_CRE_PSW} ' +
            '-X GET --header "Accept: application/json" ' +
            '"${DOCKER_URL}/artifactory/api/docker/${DOCKER_REP}/v2/${PRODUCT_NAME}/${APP_NAME}/tags/list?n=30&last=${page}"',
            returnStdout: true).trim()
          def slurper = new groovy.json.JsonSlurper()
          def jsonData = slurper.parseText(JSON)
          tmpTags = jsonData.tags
          if(tmpTags) {
            allTags += jsonData.tags
            while (tmpTags.size() == n) {
              page += n
              JSON = sh(script: '#!/bin/sh -e\n curl -s --connect-timeout 60 -u ${DOCKER_CRE_USR}:${DOCKER_CRE_PSW} ' +
                '-X GET --header "Accept: application/json" ' +
                '"${DOCKER_URL}/artifactory/api/docker/${DOCKER_REP}/v2/${PRODUCT_NAME}/${APP_NAME}/tags/list?n=30&last=${page}"',
                returnStdout: true).trim()
              jsonData = slurper.parseText(JSON)
              tmpTags = jsonData.tags
              allTags += tmpTags
            }
            def compareTags = allTags.sort().reverse().unique()
            compareTags.find { tag ->
              if(tag =~ "${env.TMP_TAG}_[0-9]{3}") {
                LATEST_TAG = tag
                return true
              }
            }
          } else {
            LATEST_TAG = ''
          }

          if (LATEST_TAG == ''){
            env.NEW_TAG = sh(script: '#!/bin/sh -e\n echo "${TMP_TAG}_001"', returnStdout: true).trim()
          } else {
            CURRENT_INCREASE=sh(script: """#!/bin/sh -e\n
              LATEST_TAG=$LATEST_TAG; echo \${LATEST_TAG##*_}|awk '{print int(\$1)}' """,
              returnStdout: true).trim()
            INCREASE=Integer.parseInt(CURRENT_INCREASE) + 1
            INCREASE=sh(script: """#!/bin/sh -e\n 
              INCREASE=$INCREASE; printf "%.3d" \$INCREASE """, returnStdout: true).trim()
            env.NEW_TAG=env.TMP_TAG + "_" + INCREASE
          }

          echo "Docker image is [ ${env.DOCKER_URL}/${env.REP}/${env.APP_NAME}:${env.NEW_TAG} ]!"
          echo "Image tag is ${env.NEW_TAG}!"
          echo '################### 获取 Tag 完成 ###################'
        }
      }
    }

    stage('普通打包') {
      when {
        environment name: 'DEPLOY_TYPE', value: 'file'
      }
      agent {
        docker {
          image 'maven:3.9.0-eclipse-temurin-11'
          args "-v /caches/maven:/var/maven/.m2 -u 1000"
        }
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
          cd target
          # chown 1000:1000 ./*.jar
          tar -zcvf ../../${PACKAGE_NAME} ./*.jar
          # chown 1000:1000 ../../${PACKAGE_NAME}
        '''
        jf "rt upload ${PACKAGE_NAME} ${REPO_PATH}"
        jf "rt build-publish"
      }
    }

    stage('镜像打包') {
      when {
        environment name: 'DEPLOY_TYPE', value: 'docker'
      }
      agent {
        label "master"
      }
      tools {
        jfrog 'jfrog-cli'
      }
      steps {
        echo '################### Package and Push ###################'
        dir("code") {
          sh '''#!/bin/sh -e
            echo ${DOCKER_CRE_PSW} | docker login -u ${DOCKER_CRE_USR} --password-stdin ${DOCKER_URL}

            if [ ! -f "Dockerfile" ]; then
              cp ../Dockerfile .
            fi
            docker build -t ${DOCKER_URL}/${DOCKER_REP}/${APP_NAME}:${NEW_TAG} .
            docker push ${DOCKER_URL}/${DOCKER_REP}/${APP_NAME}:${NEW_TAG}
          '''
        }
        jf "rt docker-push ${DOCKER_URL}/${DOCKER_REP}/${APP_NAME}:${NEW_TAG} --build-name=${BUILD_NAME} --build-number=${BUILD_NUMBER}"
        jf "rt build-publish ${BUILD_NAME} ${BUILD_NUMBER}"
      }
    }

    stage('部署') {
      agent {
        label "master"
      }
      tools {
        jfrog 'jfrog-cli'
      }
      steps {
        echo '################### Deploy ###################'
        jf "rt download ${REPO_PATH}/${PACKAGE_NAME}"
        script {
          serverList.each { ip, sshuser ->
            echo "#### 部署到 $ip ####"
            def remote = [:]
            remote.name = ip
            remote.user = sshuser
            remote.host = ip
            remote.allowAnyHosts = true

            withCredentials([sshUserPrivateKey(credentialsId: env.SERVER_SSHKEY_ID, keyFileVariable: 'identity', passphraseVariable: '', usernameVariable: 'userName')]) {
              if (env.DEPLOY_TYPE == 'file') {
                sshPut remote: remote, from: "${env.PACKAGE_NAME}", into: '/tmp/'
                sshCommand remote: remote, command: "tar -zxvf /tmp/${PACKAGE_NAME} -C ${DEPLOY_DIR}"
              } else if (env.DEPLOY_TYPE == 'docker') {
                sshCommand remote: remote, command:
                  "sed -i 's@dev/${env.APP_NAME}:\\(.*\\)@dev/${env.APP_NAME}:${env.NEW_TAG}@' /tmp/docker/docker-compose.yml"
                sshCommand remote: remote, command: "sudo docker-compose -f /data/docker/docker-compose.yml up ${env.APP_NAME} -d || true"
              }
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
