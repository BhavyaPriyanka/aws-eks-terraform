#!/bin/bash

set -e

CLUSTER_NAME="devops-lab"
REGION="us-east-1"

echo "======================================"
echo "Installing AWS Load Balancer Controller"
echo "======================================"

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME"

echo "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "Installing AWS Load Balancer Controller..."

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "Waiting for controller..."
kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system \
  --timeout=180s

echo "Checking TargetGroupBinding CRD..."
kubectl get crd targetgroupbindings.elbv2.k8s.aws

echo
echo "======================================"
echo "AWS Load Balancer Controller READY"
echo "======================================"