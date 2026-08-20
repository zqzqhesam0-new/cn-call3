FROM gradle:8.10-jdk17

WORKDIR /app

COPY . .

RUN chmod +x gradlew

RUN ./gradlew build -Dorg.gradle.java.home=

EXPOSE 8080

CMD ["./gradlew", "run"]
