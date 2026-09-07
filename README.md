# dp-mywebapp

A Spring Boot application deployed onto the DP platform, built, scanned,
and published entirely through a Jenkins pipeline, with an accompanying
Helm chart for deployment to the platform's EKS cluster.

This repository is one of three that make up the DP platform:

| Repository | Responsibility |
|---|---|
| [`dp-platform-infra`](../dp-platform-infra) | AWS infrastructure (VPC, EC2, IAM, EKS) via Terraform |
| [`dp-ansible`](../dp-ansible) | Host configuration, CI/CD toolchain, and cluster workloads |
| `dp-mywebapp` (this repo) | The application (this repo) |

For how this repo's pipeline fits into the platform's overall CI/CD flow,
see
[`dp-ansible/docs/pipeline.md`](../dp-ansible/docs/pipeline.md) §5.

---

## What's here

```
dp-mywebapp/
├── src/main/java/com/dp/mywebapp/Application.java
├── src/test/java/com/dp/mywebapp/ApplicationTest.java
├── pom.xml
├── Dockerfile
├── Jenkinsfile
└── helm/dp-mywebapp/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── hpa.yaml
        └── pdb.yaml
```

A minimal Spring Boot app exposing `/actuator/health`, which the pipeline
uses as a real readiness check — not just a build-success signal — before
the built artifact is trusted.

---

## Running locally

```bash
mvn clean test
mvn spring-boot:run
curl http://localhost:8080/actuator/health
```

Or via Docker:

```bash
docker build -t dp-mywebapp:local .
docker run -p 8080:8080 dp-mywebapp:local
```

---

## The pipeline

The `Jenkinsfile` in this repo runs, in order: compile & test → Snyk SCA
scan → package & verify → a real smoke test of the built jar (launches it
and polls `/actuator/health` before trusting it) → SonarCloud analysis →
publish to Artifactory → Docker build → Trivy image scan → push to Docker
Hub → conditionally deploy to EKS.

Two stages are hard gates, not advisory scans — a real vulnerability
stops the pipeline before the image is published:

- **Snyk SCA**, against dependencies, before packaging proceeds
- **Trivy**, `--severity HIGH,CRITICAL --exit-code 1`, against the built
  image, before it's pushed to Docker Hub

The final deploy stage only runs when the `EKS_RUNTIME_ENABLED` build
parameter is set, and it runs on the `platform-ops` Jenkins agent rather
than the `build-agent` that ran everything before it — `platform-ops` is
the only host with EKS access, so the pipeline switches agents mid-run
rather than granting that access more broadly. No AWS credentials are
stored in Jenkins for this; `platform-ops` authenticates via its
attached IAM role. Full detail in
[`dp-ansible/docs/pipeline.md`](../dp-ansible/docs/pipeline.md) §5.

---

## Deploying manually

If you need to deploy without going through Jenkins (e.g. from
`platform-ops` directly, with kubeconfig already configured):

```bash
helm lint helm/dp-mywebapp

helm upgrade --install dp-mywebapp helm/dp-mywebapp \
  --namespace dp-app \
  --create-namespace \
  --set image.repository=kingdayve/dp-mywebapp \
  --set image.tag=<build-number-or-tag> \
  --wait --timeout 5m

kubectl rollout status deployment/dp-mywebapp --namespace dp-app --timeout=5m
```

The chart's autoscaling (`hpa.yaml`) and disruption budget (`pdb.yaml`)
templates are both gated behind `.Values` toggles — check `values.yaml`
before deploying if you want to confirm they're enabled.
