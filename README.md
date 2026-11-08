# Production Platform & SRE Reference Platform

[![CI/CD Pipeline](https://github.com/Anyah11/production-platform-blueprint/actions/workflows/deploy.yml/badge.svg)](https://github.com/Anyah11/production-platform-blueprint/actions/workflows/deploy.yml)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS%20%7C%20OIDC-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Telemetry-F46800?logo=grafana&logoColor=white)](https://grafana.com/)

A hands-on platform engineering and SRE reference implementation demonstrating automated cloud-native infrastructure delivery, keyless CI/CD with AWS IAM OpenID Connect (OIDC), multi-stage container packaging, dynamic service discovery, and declarative Prometheus alerting on Amazon EKS.

---

## Architecture Topology

```text
                               +-----------------------------+
                               |        GitHub Actions       |
                               | (OIDC Short-Lived JWT Auth) |
                               +--------------+--------------+
                                              |
                     +------------------------+------------------------+
                     |                                                 |
                     v                                                 v
        +-------------------------+                       +-------------------------+
        |     Amazon ECR Repo     |                       |     Amazon EKS v1.31    |
        |   (OCI Container Build) |                       |     (AWS us-east-1)     |
        +-------------------------+                       +------------+------------+
                                                                       |
                          +--------------------------------------------+--------------------------------------------+
                          |                                                                                         |
                          v                                                                                         v
              +-----------------------+                                                                 +-----------------------+
              |   default Namespace   |                                                                 |  monitoring Namespace |
              |  - demo-api Pods (2)  |<----------------- Scrape /metrics (15s interval) ----------------|  - Prometheus Pods    |
              |  - demo-api-svc       |                                                                 |  - Grafana Dashboards |
              |  - ServiceMonitor     |------------------ Evaluates 5xx error rules ------------------->|  - Alertmanager       |
              +-----------------------+                                                                 +-----------------------+
```

---

## Technical Highlights & Engineering Decisions

### 1. Keyless AWS OIDC CI/CD (Zero Long-Lived Static Keys)
- Configured an AWS IAM OpenID Connect (OIDC) identity provider (`token.actions.githubusercontent.com`) paired with an IAM role (`github-actions-deployer-role`).
- Scope-restricted using the IAM condition claim `token.actions.githubusercontent.com:sub` with `StringLike` evaluation matching `repo:Anyah11/production-platform-blueprint:*`.
- Eliminates hardcoded `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets, adopting short-lived STS tokens for all automated deployments.
- *Architecture Decision Record:* [`docs/adr/002-oidc-trust-scope.md`](docs/adr/002-oidc-trust-scope.md).

### 2. Multi-Stage Containerization & Hardening
- **Go REST Microservice:** Lightweight HTTP service exposing `/`, `/healthz` (Kubernetes liveness/readiness), `/metrics` (Prometheus exposition), and `/fault` (synthetic 5xx error injection).
- **Hardened Packaging:** Built with a multi-stage `Dockerfile` (`golang:alpine` builder with `CGO_ENABLED=0` and stripped debug symbols `-ldflags="-s -w"`), running on minimal `alpine:3.20` as unprivileged user `appuser` (UID `10001`).

### 3. Observability & SRE Incident Response
- **Prometheus Operator:** Installed via the `kube-prometheus-stack` Helm chart.
- **Dynamic Service Discovery:** Deployed a CoreOS `ServiceMonitor` CRD targeting the `demo-api-svc` Service over port `http` (`8080`), automatically updating scrape targets as pods scale.
- **Declarative PrometheusRule:** Configured a threshold rule (`DemoApiHighErrorRate`) that tracks 5xx ratios across a 2-minute sliding window and fires when error rates exceed 5% continuously for 1 minute.

---

## Proof of Work & Verification Telemetry

### 1. Prometheus Target Discovery
Prometheus discovering both running application pods dynamically via the `ServiceMonitor` across worker nodes (`2 / 2 UP`):

![Prometheus Target Discovery](docs/screenshots/prometheus-targets-up.png)

### 2. Live Telemetry & Traffic Spike in Grafana
Real-time traffic telemetry and request rate visualization configured in Grafana using PromQL query `sum(rate(http_requests_total[1m])) by (status)`:

![Grafana HTTP Rate Panel](docs/screenshots/grafana-http-rate.png)

### 3. Keyless GitHub Actions Pipeline Run
Automated pipeline execution performing Go static checks, container compilation, ECR push, and zero-downtime rolling deployment to EKS via IAM OIDC:

![GitHub Actions Success](docs/screenshots/github-actions-success.png)

### 4. Synthetic Fault Injection & Alert Evaluation
To validate incident detection without waiting for organic production failures, synthetic failure traffic was injected to test rule evaluation:

1. **Traffic Injection:** Forwarded the application service locally (`kubectl port-forward svc/demo-api-svc 8080:80`) and executed a burst of 100 requests to `/fault`:
   ```bash
   for i in {1..100}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/fault; sleep 0.1; done
   ```
2. **Alert Lifecycle & Timings:**
   - **Peak Error Ratio:** 100% during the burst (breaching the 5% threshold).
   - **Time to `Pending`:** ~15–30 seconds (1–2 scrape intervals for PromQL expression evaluation).
   - **Time to `Firing`:** ~1 minute 20 seconds total (~20s discovery + 60s sustained `for: 1m` condition).

![Prometheus Alert Firing](docs/screenshots/prometheus-alert-firing.png)

*Detailed Simulation Write-up:* [`docs/incident-simulation.md`](docs/incident-simulation.md).

---

## Documentation & Decision Records

Detailed platform architecture records and troubleshooting retrospectives are maintained in `docs/`:

- **Architecture Decision Records:**
  - [`ADR-001: Amazon EKS vs. Lightweight K3s for Portfolio Reference Platform`](docs/adr/001-eks-over-k3s.md)
  - [`ADR-002: AWS IAM OIDC Subject Claim Trust Scoping and Wildcard Tradeoffs`](docs/adr/002-oidc-trust-scope.md)
  - [`ADR-003: Raw Manifests with Kube-Prometheus-Stack Helm Installation`](docs/adr/003-raw-manifests-vs-helm.md)
- **Operational Logs:**
  - [`Incident Simulation & Alert Timing Report`](docs/incident-simulation.md)
  - [`Platform Engineering Challenges & Debugging Log`](docs/challenges-log.md)

---

## Project Structure

```text
├── .github/
│   └── workflows/
│       └── deploy.yml            # OIDC automated build, test, and EKS rollout pipeline
├── app/
│   ├── Dockerfile                # Multi-stage, non-root unprivileged container build
│   ├── go.mod                    # Go dependencies definition
│   ├── go.sum                    # Dependency checksum verification
│   └── main.go                   # Go HTTP service with Prometheus & /fault injection
├── docs/
│   ├── adr/                      # Architectural Decision Records (ADRs)
│   ├── challenges-log.md         # Operational debug notes and root cause analyses
│   ├── incident-simulation.md    # SRE fault injection and alert timing report
│   └── screenshots/              # Portfolio proof-of-work captures
│       ├── github-actions-success.png
│       ├── grafana-http-rate.png
│       ├── prometheus-alert-firing.png
│       └── prometheus-targets-up.png
├── k8s/
│   ├── deployment.yaml           # Deployment (2 replicas, probes) and ClusterIP Service
│   ├── servicemonitor.yaml       # CoreOS ServiceMonitor for automated metric scraping
│   └── prometheus-rule.yaml      # SRE alerting rule for 5xx error rate spikes
└── terraform/
    ├── eks.tf                    # Amazon EKS cluster and managed node group configuration
    ├── github_oidc.tf            # AWS IAM OIDC Provider and deployer role definition
    ├── outputs.tf                # Cluster endpoints and OIDC role ARNs
    ├── providers.tf              # AWS and Kubernetes provider versions
    ├── variables.tf              # Region and cluster sizing inputs
    └── vpc.tf                    # Multi-AZ VPC, subnets, and NAT Gateway layout
```

---

## Deployment & Setup Guide

### 1. Prerequisites
- AWS CLI v2 configured with active credentials
- Terraform `>= 1.5.0`
- `kubectl` matching cluster version (`v1.31`)
- Helm `>= 3.12.0`
- Docker CLI or Docker Desktop

### 2. Infrastructure Provisioning
```bash
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --region us-east-1 --name platform-eks-cluster
```

### 3. Observability Stack Installation
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### 4. Deploy Application & Observability Custom Resources
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/servicemonitor.yaml
kubectl apply -f k8s/prometheus-rule.yaml
```

---

## Teardown & Cloud Cost Prevention

To prevent unneeded charges for the EKS Control Plane ($0.10/hr), NAT Gateways ($0.045/hr), and EC2 worker nodes:

```bash
# 1. Clean up in-cluster workloads and Helm releases
kubectl delete -f k8s/ --ignore-not-found=true
helm uninstall monitoring -n monitoring --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

# 2. Destroy cloud infrastructure
cd terraform
terraform destroy
```

### Manual Verification
Confirm all dynamic or ephemeral resources have ceased billing in the AWS Management Console or via CLI:
- **Elastic IPs:** Ensure no unattached allocations remain (`AssociationId == null`).
- **EBS Volumes:** Confirm no lingering `available` persistent disks from Prometheus exist.
- **NAT Gateways & Instances:** Verify all nodes are `terminated` and NAT Gateways are `deleted`.

---

## Current Platform Limitations & Production Roadmap

This blueprint intentionally targets portfolio validation and cost efficiency. For high-scale production usage, the following upgrades are recommended:
- **Remote Terraform State:** Currently using local state (`terraform.tfstate`). Production requires an S3 backend with DynamoDB state locking to prevent concurrent state corruption.
- **Alertmanager Notification Routing:** Alert rules currently terminate at Prometheus UI verification. Production clusters require routing to external receivers (e.g., Slack webhooks, PagerDuty, or Opsgenie).
- **Ingress & TLS Termination:** Service access is currently demonstrated via `kubectl port-forward`. Production traffic should route through AWS Load Balancer Controller (ALB Ingress) with ACM-backed TLS termination.
- **GitOps Agent:** The pipeline currently uses push-based CI/CD via GitHub Actions. Upgrading to a pull-based GitOps reconciler (ArgoCD or Flux) would eliminate the need for GitHub Actions to hold cluster deployment credentials.
