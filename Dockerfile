# ============================================================================
# DP MyWebApp Runtime Image
# ============================================================================

FROM gcr.io/distroless/java21-debian12:nonroot

LABEL org.opencontainers.image.title="DP MyWebApp"
LABEL org.opencontainers.image.description="DP DevSecOps Platform Java Application"

WORKDIR /app

COPY --chown=nonroot:nonroot target/dp-mywebapp-1.0.0-SNAPSHOT.jar /app/app.jar

USER nonroot:nonroot

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
