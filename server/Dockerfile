FROM gradle:8.10-jdk17

WORKDIR /app

COPY . .

RUN chmod +x gradlew

RUN echo "org.gradle.java.home=/opt/java/openjdk" > /tmp/gradle.properties

RUN ./gradlew shadowJar --no-daemon --gradle-user-home /tmp

EXPOSE 8080

CMD ["java", "-jar", "build/libs/cn-call-server.jar"]
