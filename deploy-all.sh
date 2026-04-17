#!/bin/bash
# deploy-all.sh — Deploy complete Kubernetes Auto-Scaling stack

set -e

echo "=== Deploying Kubernetes Auto-Scaling Architecture ==="

echo "[1/7] Creating namespaces..."
kubectl apply -f namespace.yaml

echo "[2/7] Deploying application..."
kubectl apply -f deployment.yaml

echo "[3/7] Deploying service..."
kubectl apply -f service.yaml

echo "[4/7] Deploying ingress..."
kubectl apply -f ingress.yaml

echo "[5/7] Deploying HPA (Horizontal Pod Autoscaler)..."
kubectl apply -f hpa.yaml

echo "[6/7] Deploying VPA (Vertical Pod Autoscaler - Recommendation mode)..."
kubectl apply -f vpa.yaml

echo "[7/7] Deploying KEDA ScaledObjects..."
kubectl apply -f keda-scaledobject.yaml

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Verifying resources:"
kubectl get deployment -n production
kubectl get hpa -n production
kubectl get vpa -n production
kubectl get scaledobject -n production
echo ""
echo "Watch HPA in real time:"
echo "  kubectl get hpa -n production -w"
echo ""
echo "Load test to trigger HPA:"
echo "  kubectl run -i --tty load-generator --image=busybox /bin/sh"
echo "  while true; do wget -q -O- http://python-devops-service.production.svc/; done"
