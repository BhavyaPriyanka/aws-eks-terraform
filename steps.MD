# 05-EKS

This module creates and manages an Amazon EKS cluster, managed node groups, EKS add-ons, Bastion access, and Cluster Autoscaler.

## Prerequisites

The following resources must already exist:

- VPC
- Private subnets
- EKS cluster security group
- EKS node security group
- Bastion IAM role

These resources are created by the previous Terraform modules.

The EKS module reads the required values from AWS Systems Manager Parameter Store:

```text
/localhelp/dev/vpc_id
/localhelp/dev/private_subnet_ids
/localhelp/dev/cluster_sg_id
/localhelp/dev/node_sg_id
```

## EKS Cluster

| Configuration | Value |
|---|---|
| Project | `localhelp` |
| Environment | `dev` |
| Region | `us-east-1` |
| Cluster Name | `localhelp-dev` |
| Kubernetes Version | `1.32` |
| Endpoint | Public |
| Worker Subnets | Private |

The cluster initially uses Kubernetes `1.32` so that the Blue/Green Kubernetes upgrade can be practiced.

## SSH Key Pair

Terraform creates an AWS EC2 key pair named `eks`.

The public key is read from:

```text
~/.ssh/eks.pub
```

Check that the key exists:

```bash
ls -l ~/.ssh/eks.pub
```

## EKS Add-ons

The following EKS add-ons are enabled:

- CoreDNS
- EKS Pod Identity Agent
- kube-proxy
- VPC CNI

## EKS Access Entry

The Bastion IAM role is added to the EKS cluster using an EKS Access Entry.

The Bastion receives:

```text
AmazonEKSClusterAdminPolicy
```

This allows the Bastion to access and manage the Kubernetes cluster using `kubectl`.

## Managed Node Groups

This project uses a Blue/Green node group strategy.

### Blue Node Group

Blue is the initial worker node group.

| Configuration | Value |
|---|---|
| Node Group | `blue` |
| Kubernetes Version | `1.32` |
| Capacity Type | `SPOT` |
| Desired Size | `2` |
| Minimum Size | `2` |
| Maximum Size | `10` |

### Green Node Group

Green is created during the Kubernetes upgrade.

| Configuration | Value |
|---|---|
| Node Group | `green` |
| Kubernetes Version | `1.33` |
| Capacity Type | `SPOT` |
| Desired Size | `2` |
| Minimum Size | `2` |
| Maximum Size | `10` |

Node group versions are explicitly defined so that changing the EKS control-plane version does not automatically upgrade the Blue node group.

## Blue/Green Kubernetes Upgrade

The upgrade is performed without directly upgrading the existing Blue node group.

### Initial State

```text
EKS Control Plane
       |
      1.32
       |
       +---- Blue Nodes
              1.32
              2 Nodes
```

### Step 1: Upgrade the Control Plane

Upgrade the EKS control plane:

```text
1.32 → 1.33
```

Blue remains on Kubernetes `1.32`.

```text
EKS Control Plane
       |
      1.33
       |
       +---- Blue Nodes
              1.32
```

### Step 2: Create Green

Create the Green node group with Kubernetes `1.33`.

```text
EKS Control Plane
       |
      1.33
       |
       +---- Blue Nodes
       |       1.32
       |
       +---- Green Nodes
               1.33
```

### Step 3: Verify Green

Check the nodes:

```bash
kubectl get nodes -o wide
```

Verify that the Green nodes are:

- `Ready`
- Running Kubernetes `1.33`

Check workloads:

```bash
kubectl get pods -A -o wide
```

### Step 4: Cordon Blue

Cordon a Blue node:

```bash
kubectl cordon <BLUE_NODE>
```

Cordon prevents new workloads from being scheduled on the node.

### Step 5: Drain Blue

Drain the Blue node:

```bash
kubectl drain <BLUE_NODE> \
  --ignore-daemonsets \
  --delete-emptydir-data
```

Drain Blue nodes one at a time.

Workloads should be rescheduled onto Green nodes.

### Step 6: Verify Workloads

Check nodes:

```bash
kubectl get nodes -o wide
```

Check pods:

```bash
kubectl get pods -A -o wide
```

Verify that applications are running successfully on Green nodes.

### Step 7: Remove Blue

After all workloads have successfully migrated to Green, remove the Blue node group using Terraform.

Do not remove Blue before verifying Green.

## Final State

```text
EKS Control Plane
       |
      1.33
       |
       +---- Green Nodes
              1.33
              2 Nodes

Blue Node Group
     Removed
```

The final environment should have:

- EKS Control Plane: `1.33`
- Green Node Group: `1.33`
- Blue Node Group: Removed
- Applications: Healthy
- Workloads: Running on Green nodes

## Cluster Autoscaler

Cluster Autoscaler automatically adjusts the number of worker nodes based on workload requirements.

This project uses a dedicated IAM role for Cluster Autoscaler through IRSA.

```text
Kubernetes Service Account
          |
          v
     EKS OIDC Provider
          |
          v
        IAM Role
          |
          v
      IAM Policy
          |
          v
    AWS Auto Scaling
```

The Cluster Autoscaler Service Account is:

```text
kube-system/cluster-autoscaler
```

The IAM role is attached using:

```text
eks.amazonaws.com/role-arn
```

## Cluster Autoscaler IAM Permissions

The Cluster Autoscaler IAM policy includes:

```text
autoscaling:DescribeAutoScalingGroups
autoscaling:DescribeAutoScalingInstances
autoscaling:DescribeLaunchConfigurations
autoscaling:DescribeScalingActivities
autoscaling:DescribeTags
ec2:DescribeImages
ec2:DescribeInstanceTypes
ec2:DescribeLaunchTemplateVersions
```

Scaling permissions:

```text
autoscaling:SetDesiredCapacity
autoscaling:TerminateInstanceInAutoScalingGroup
autoscaling:UpdateAutoScalingGroup
```

## Cluster Autoscaler Helm

Cluster Autoscaler is installed using Helm.

The Helm release creates the Service Account:

```text
cluster-autoscaler
```

in the:

```text
kube-system
```

namespace.

The Service Account receives the IAM role using the IRSA annotation:

```text
eks.amazonaws.com/role-arn
```

## Verification

### Check EKS Cluster

```bash
aws eks describe-cluster \
  --name localhelp-dev \
  --region us-east-1
```

### Check Nodes

```bash
kubectl get nodes -o wide
```

### Check All Pods

```bash
kubectl get pods -A
```

### Check Cluster Autoscaler

```bash
kubectl get pods -n kube-system
```

### Check Cluster Autoscaler Logs

```bash
kubectl logs \
  -n kube-system \
  deployment/cluster-autoscaler
```

### Check Service Account

```bash
kubectl get sa cluster-autoscaler \
  -n kube-system \
  -o yaml
```

### Check IAM Role Annotation

```bash
kubectl get sa cluster-autoscaler \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

## Terraform Commands

### Initialize

```bash
terraform init
```

### Format

```bash
terraform fmt
```

### Validate

```bash
terraform validate
```

### Plan

```bash
terraform plan
```

### Apply

```bash
terraform apply
```

### Check State

```bash
terraform state list
```

### Refresh State

```bash
terraform plan -refresh-only
```

### Destroy

```bash
terraform destroy
```

## Terraform State Lock

If Terraform reports a state-lock error, first check whether another Terraform process is running:

```bash
ps aux | grep terraform
```

If the lock is stale, use the lock ID shown by Terraform:

```bash
terraform force-unlock <LOCK_ID>
```

Do not use `-lock=false` unless there is a specific reason to bypass Terraform state locking.

## Important Rules

Do not directly upgrade the Blue managed node group during the Blue/Green migration.

Do not delete Blue before Green is verified.

Do not use:

```bash
kubectl drain --force
```

unless absolutely necessary.

The preferred migration process is:

```text
Create Green
    |
    v
Verify Green
    |
    v
Cordon Blue
    |
    v
Drain Blue
    |
    v
Verify Workloads
    |
    v
Delete Blue
```

## Complete Upgrade Flow

```text
Kubernetes 1.32
      |
      v
EKS Control Plane 1.32
      |
      +---- Blue Nodes 1.32
      |
      v
Upgrade Control Plane
      |
      v
EKS Control Plane 1.33
      |
      +---- Blue Nodes 1.32
      |
      +---- Green Nodes 1.33
                    |
                    v
              Verify Green
                    |
                    v
               Cordon Blue
                    |
                    v
                Drain Blue
                    |
                    v
            Workloads → Green
                    |
                    v
            Verify Applications
                    |
                    v
              Delete Blue
                    |
                    v
          Green Nodes 1.33
```

## Final Objective

The final objective is:

```text
EKS Control Plane : 1.33
Green Nodes       : 1.33
Blue Nodes        : Removed
Applications      : Healthy
Workloads         : Running on Green
```
