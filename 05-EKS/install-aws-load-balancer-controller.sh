
#!/bin/bash

set -Eeuo pipefail

CLUSTER_NAME="devops-lab"
REGION="us-east-1"
AWS_ACCOUNT_ID="837206354502"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "======================================"
echo "Preparing AWS and EKS authentication"
echo "======================================"

# Refresh AWS credentials if using an expiring assumed role,
# SSO session, or other temporary credential source.
aws sts get-caller-identity

echo "Authenticating Docker with private ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$ECR_REGISTRY"

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME"

echo "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts --force-update
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
echo "AWS LOAD BALANCER CONTROLLER READY"
echo "ECR authentication refreshed"
echo "======================================"
