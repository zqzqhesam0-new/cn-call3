FROM gradle:8.10-jdk17

WORKDIR /app

COPY . .

RUN chmod +x gradlew
RUN ./gradlew build

EXPOSE 8080

CMD ["./gradlew", "run"]
