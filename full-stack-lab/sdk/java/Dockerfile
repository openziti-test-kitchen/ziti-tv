# Build the fat jar with Gradle on a Temurin 21 JDK, then run on a Temurin 21 JRE.
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src

# Gradle wrapper is not vendored, so install Gradle from the distribution.
ENV GRADLE_VERSION=8.10.2
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -s "/opt/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle \
    && rm /tmp/gradle.zip

# Resolve dependencies first for better layer caching.
COPY settings.gradle build.gradle ./
RUN gradle --no-daemon dependencies > /dev/null 2>&1 || true

COPY src ./src
RUN gradle --no-daemon clean jar

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=build /src/build/libs/zo-sdk-java.jar /app/app.jar

ENV ZITI_IDENTITY=/ziti/id.json
ENV SELF_LANG=java

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# ENTRYPOINT dispatches on APP ROLE, e.g. `docker run zo-sdk-java echo client`.
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["echo", "server"]
