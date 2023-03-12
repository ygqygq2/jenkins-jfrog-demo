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
    DOCKER_URL = 'reg.k8snb.com'
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
          env.APP_NAME = env.JOB_NAME.split('_')[-1].toLowerCase();
          env.ENV_TAG = env.JOB_NAME.split('_')[0];
          env.PRODUCT_NAME = env.JOB_NAME.split('_')[1];
          if (env.DEPLOY_TYPE == 'file') {
            env.REPO_PATH = "generic-local/${env.PRODUCT_NAME}/${env.APP_NAME}"
            env.PACKAGE_NAME = "${env.APP_NAME}-${env.DEPLOY_BRANCH}-${env.BUILD_NUMBER}.tar.gz"
          } else if (env.DEPLOY_TYPE == 'docker') {
            env.REPO_PATH = "${env.DOCKER_REP}/${env.PRODUCT_NAME}/${env.APP_NAME}".toLowerCase()
            // 避免后面错误
            env.PACKAGE_NAME = ''
            env.TMP_TAG = sh(script: '#!/bin/sh -e\n echo "${DEPLOY_BRANCH}"|sed "s/[^[:alnum:]._-]/-/g"',
              returnStdout: true).trim()
          } else {
            echo "部署类型错误"
            currentBuild.result = 'ABORTED'
            sh "exit 1"
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
          env.page = 0
          // 一次查询的数量
          def n = 30
          def allTags = []
          def LATEST_TAG = ''
          env.jsonFile = 'tags.json'
          sh '''
            curl -s --connect-timeout 60 -u "${DOCKER_CRE_USR}:${DOCKER_CRE_PSW}" \
            -X GET --header "Accept: application/json" \
            "https://${DOCKER_URL}/artifactory/api/docker/${DOCKER_REP}/v2/${PRODUCT_NAME}/${APP_NAME}/tags/list?n=30&last=${page}" \
            2>&1 > "${jsonFile}"
          '''
          def JSON = readJSON file: jsonFile, returnPojo: true
          tmpTags = JSON.tags
          if(tmpTags) {
            allTags += tmpTags
            while (tmpTags.size() >= n) {
              env.page += n
              sh '''
                curl -s --connect-timeout 60 -u "${DOCKER_CRE_USR}:${DOCKER_CRE_PSW}" \
                -X GET --header "Accept: application/json" \
                "https://${DOCKER_URL}/artifactory/api/docker/${DOCKER_REP}/v2/${PRODUCT_NAME}/${APP_NAME}/tags/list?n=30&last=${page}" \
                2>&1 > "${jsonFile}"
              '''
              JSON = readJSON file: jsonFile, returnPojo: true
              tmpTags = JSON.tags
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

          echo "Docker image is [ ${env.DOCKER_URL}/${env.REPO_PATH}:${env.NEW_TAG} ]!"
          echo "Image tag is ${env.NEW_TAG}!"
          echo '################### 获取 Tag 完成 ###################'
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
        sh """#!/bin/sh -e
          cd code
          mvn -B install -f pom.xml -s ../conf/settings.xml -DskipTests
          cd target
          # chown 1000:1000 ./*.jar
          tar -zcvf ../../${PACKAGE_NAME} ./*.jar
          # chown 1000:1000 ../../${PACKAGE_NAME}
        """
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
            echo "${DOCKER_CRE_PSW}" | docker login -u ${DOCKER_CRE_USR} --password-stdin ${DOCKER_URL}

            if [ ! -f "Dockerfile" ]; then
              cp ../Dockerfile .
              cp -r ../conf .
            fi
            docker build -t ${DOCKER_URL}/${REPO_PATH}:${NEW_TAG} .
            docker push ${DOCKER_URL}/${REPO_PATH}:${NEW_TAG}
          '''
        }
        jf "rt build-publish ${JOB_NAME} ${BUILD_NUMBER}"
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
        script {
          if (env.DEPLOY_TYPE == 'file') {
            jf "rt download ${REPO_PATH}/${PACKAGE_NAME}"
          }
          serverList.each { ip, sshuser ->
            echo "#### 部署到 $ip ####"
            def remote = [:]
            remote.name = ip
            remote.user = sshuser
            remote.host = ip
            remote.allowAnyHosts = true

            withCredentials([sshUserPrivateKey(credentialsId: env.SERVER_SSHKEY_ID, keyFileVariable: 'identity',
              passphraseVariable: '', usernameVariable: 'userName')]) {
              remote.identityFile = identity
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
