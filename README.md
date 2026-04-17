# Kubernetes Auto-Scaling Architecture
> Production-grade HPA + VPA + KEDA + Cluster Autoscaler

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![KEDA](https://img.shields.io/badge/KEDA-2.13-blue?style=for-the-badge)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)

---

## Architecture Overview

```
User Traffic / Events
        ↓
Ingress Controller (NGINX)
        ↓
Application Pods (Flask)
        ↓
metrics-server + Prometheus
        ↓
HPA / KEDA (scale decision)
        ↓
Cluster Autoscaler (new nodes)
        ↓
Grafana + AlertManager
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| kubectl | v1.28+ | [Install](https://kubernetes.io/docs/tasks/tools/) |
| Kubernetes cluster | v1.28+ | Minikube / EKS / GKE / AKS |
| Helm | v3.12+ | [Install](https://helm.sh/docs/intro/install/) |
| Docker | 24+ | [Install](https://docs.docker.com/get-docker/) |

---

## Execution Steps

### Step 1 — Start Kubernetes Cluster (Minikube)

```bash
minikube start --cpus=4 --memory=8192 --driver=docker
minikube addons enable ingress
minikube addons enable metrics-server
kubectl get nodes
```

### Step 2 — Install metrics-server (required for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

### Step 3 — Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
kubectl get pods -n keda
```

### Step 4 — Deploy Application

```bash
# Replace YOUR_DOCKERHUB_USERNAME with your Docker Hub username
sed -i 's/YOUR_DOCKERHUB_USERNAME/yourusername/g' deployment.yaml

kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

kubectl get pods -n production
kubectl get svc -n production
```

### Step 5 — Deploy HPA

```bash
kubectl apply -f hpa.yaml
kubectl get hpa -n production -w
kubectl describe hpa python-devops-app-hpa -n production
```

### Step 6 — Deploy VPA (Recommendation mode only)

```bash
kubectl apply -f https://github.com/kubernetes/autoscaler/raw/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
kubectl apply -f vpa.yaml
kubectl describe vpa python-devops-app-vpa -n production
```

### Step 7 — Deploy KEDA ScaledObjects

```bash
kubectl apply -f keda-scaledobject.yaml
kubectl get scaledobject -n production
kubectl describe scaledobject rabbitmq-worker-scaler -n production
```

### Step 8 — Deploy Cluster Autoscaler (AWS EKS only)

```bash
# Update ACCOUNT_ID and cluster name first
sed -i 's/ACCOUNT_ID/your-aws-account-id/g' cluster-autoscaler.yaml
sed -i 's/my-cluster/your-eks-cluster-name/g' cluster-autoscaler.yaml
kubectl apply -f cluster-autoscaler.yaml
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
```

---

## Testing Auto-Scaling

### Test HPA — Trigger CPU Scale-Out

```bash
# Terminal 1: Watch HPA
kubectl get hpa -n production -w

# Terminal 2: Generate CPU load
kubectl run load-generator \
  --image=busybox --restart=Never -n production \
  -- /bin/sh -c "while true; do wget -q -O- http://python-devops-service.production.svc/; done"

# Watch pods scale up
kubectl get pods -n production -w

# Stop load and watch scale-down (5 min stabilization window)
kubectl delete pod load-generator -n production
```

### Test KEDA — Scale to Zero

```bash
# With empty queue → KEDA scales deployment to 0 pods
kubectl get pods -n production | grep message-processor

# Publish messages to queue → KEDA scales up automatically
kubectl get scaledobject -n production -w
```

### Check VPA Recommendations

```bash
kubectl get vpa python-devops-app-vpa -n production -o json | \
  jq '.status.recommendation.containerRecommendations'
```

---

## Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Access Grafana dashboard
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# URL: http://localhost:3000  |  admin / prom-operator

# Watch all scaling resources live
watch kubectl get hpa,vpa,scaledobject,pods -n production
```

---

## Cleanup

```bash
kubectl delete -f keda-scaledobject.yaml
kubectl delete -f hpa.yaml
kubectl delete -f vpa.yaml
kubectl delete -f deployment.yaml
kubectl delete -f service.yaml
kubectl delete -f namespace.yaml
helm uninstall keda -n keda
```

---

## Files

| File | Description |
|------|-------------|
| `deployment.yaml` | Flask app with probes + security context |
| `service.yaml` | NodePort service (port 30007) |
| `ingress.yaml` | NGINX ingress with TLS |
| `hpa.yaml` | HPA v2: CPU + memory + custom metrics |
| `vpa.yaml` | VPA in Recommendation mode |
| `keda-scaledobject.yaml` | KEDA: RabbitMQ, Kafka, Cron, SQS scalers |
| `cluster-autoscaler.yaml` | Cluster Autoscaler for AWS EKS |
| `namespace.yaml` | production + staging namespaces |
| `deploy-all.sh` | One-shot deploy script |
| `ARCHITECTURE.md` | Full diagram + LinkedIn post + storyboard |
