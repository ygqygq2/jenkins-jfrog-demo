FROM maven:3.9.0-eclipse-temurin-8-alpine AS builder

WORKDIR /usr/src/mymaven

COPY . .
COPY conf/settings.xml /usr/share/maven/conf/settings.xml

RUN mvn -B install --file pom.xml

# FROM openjdk:8-jdk-alpine

# LABEL maintainer "ygqygq2@qq.com"

# ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$JAVA_HOME/lib:/data/lib
# 注意生成的 jar 包名
# COPY --from=builder /usr/src/mymaven/target/eureka-server-*.jar /app.jar
# 
# CMD ["java", "-Duser.timezone=GMT+08", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app.jar"]
