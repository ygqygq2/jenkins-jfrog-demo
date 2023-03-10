# jenkins-jfrog-demo
jenkins jfrog container registry 集成
- [x] docker maven 打包，普通文件方式上传至 Artifactory，并远程 ssh 执行命令部署
- [] docker maven 打包，docker 方式上传至 Artifactory，并远程 ssh docker-compose 部署

# 环境
- [x] Docker 20.10.12
- [x] Docker Compose v2.2.3
- [x] Jenkins 2.375.3
- [x] JFrog Container Registry license 7.55.6

# 安装
- docker ce，略
- docker-compose，略
- jenkins，使用当前目录下 `docker-compose.yml` 启动
- jfrog container registry 下载解压，运行即可，`/opt/artifactory-jcr-7.55.6/app/bin/artifactoryctl start`

# 配置
`chmod 666 /var/run/docker.sock` 使 jenkins 可以访问 docker
![](images/2023-03-10-11-19-00.png)

Jenkins 系统管理配置 JFrog 平台信息，用户密码，token 凭证应该都是支持的。
![](images/2023-03-10-10-28-53.png)

Jenkins 配置 jfrog-cli 工具，内网推荐使用直接下载解压，只是需要准备一个可以匿名下载的 URL
![](images/2023-03-10-10-31-59.png)

![](images/2023-03-10-10-34-00.png)

jfrog-cli-remote 配置的地址为：https://releases.jfrog.io/artifactory/jfrog-cli/
![](images/2023-03-10-10-36-46.png)

# jfrog-cli 测试
```Jenkinsfile
pipeline {
    agent any
    tools {
        jfrog 'jfrog-cli'
    }
    stages {
        stage('Testing') {
            steps {
                // Show the installed version of JFrog CLI.
                jf '-v'

                // Show the configured JFrog Platform instances.
                jf 'c show'

                // Ping Artifactory.
                jf 'rt ping'

            }
        }
    }
}
```
![](images/2023-03-10-10-39-06.png)

参考资料：    
[1] https://github.com/jfrog/jenkins-jfrog-plugin#readme    
[2] https://jfrog.com/whitepaper/best-practices-structuring-naming-artifactory-repositories/
