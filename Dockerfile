FROM maven:3.9.0-eclipse-temurin-11 AS builder

WORKDIR /usr/src/mymaven

COPY . .
COPY conf/settings.xml /usr/share/maven/conf/settings-docker.xml

RUN mvn -B install -f pom.xml -s /usr/share/maven/conf/settings-docker.xml

FROM eclipse-temurin:11

LABEL maintainer "ygqygq2@qq.com"

# 注意生成的 jar 包名
COPY --from=builder /usr/src/mymaven/target/my-app*.jar /app.jar

CMD ["java", "-Duser.timezone=GMT+08", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app.jar"]
