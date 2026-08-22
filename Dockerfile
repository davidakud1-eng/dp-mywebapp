# ============================================================================
# DP MyWebApp Runtime Image
# ============================================================================

FROM eclipse-temurin:17-jre

LABEL org.opencontainers.image.title="DP MyWebApp"
LABEL org.opencontainers.image.description="DP DevSecOps Platform Java Application"

WORKDIR /app

COPY target/dp-mywebapp-1.0.0-SNAPSHOT.jar app.jar

USER 10001

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
