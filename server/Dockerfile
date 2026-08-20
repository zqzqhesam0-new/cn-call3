FROM gradle:8.10-jdk17

WORKDIR /app

COPY . .

RUN chmod +x gradlew

RUN env -u GRADLE_OPTS -u JAVA_HOME ./gradlew build

EXPOSE 8080

CMD ["./gradlew", "run"]
