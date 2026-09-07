# 05-EKS

This module creates an Amazon EKS cluster with managed node groups, EKS add-ons, Bastion access, and Cluster Autoscaler.

## Prerequisites

The following resources must already exist:

- VPC
- Private subnets
- EKS cluster security group
- EKS node security group
- Bastion IAM role

These values are read from AWS Systems Manager Parameter Store.

Example parameters:

/localhelp/dev/vpc_id
/localhelp/dev/private_subnet_ids
/localhelp/dev/cluster_sg_id
/localhelp/dev/node_sg_id

## EKS Cluster

Cluster configuration:

- Project: localhelp
- Environment: dev
- Region: us-east-1
- Cluster name: localhelp-dev
- Kubernetes version: 1.32
- Cluster endpoint: Public
- Worker nodes: Private subnets

The cluster starts with Kubernetes 1.32 because this project is used to practice a Blue/Green Kubernetes upgrade to 1.33.

## SSH Key Pair

Terraform creates an AWS key pair named `eks`.

The public key is read from:

`~/.ssh/eks.pub`

Verify that the key exists before running Terraform:

`ls -l ~/.ssh/eks.pub`

## EKS Add-ons

The following EKS add-ons are enabled:

- CoreDNS
- EKS Pod Identity Agent
- kube-proxy
- VPC CNI

## EKS Access Entry

The Bastion IAM role is added to the EKS cluster using an EKS Access Entry.

The Bastion receives:

`AmazonEKSClusterAdminPolicy`

This allows the Bastion to access the Kubernetes cluster using `kubectl`.

## Managed Node Groups

The project uses a Blue/Green node group strategy.

Blue is the initial node group.

Blue configuration:

- Kubernetes version: 1.32
- Capacity type: SPOT
- Desired size: 2
- Minimum size: 2
- Maximum size: 10

Green is created during the Kubernetes upgrade.

Green configuration:

- Kubernetes version: 1.33
- Capacity type: SPOT
- Desired size: 2
- Minimum size: 2
- Maximum size: 10

The node group versions are explicitly defined so that changing the EKS control plane version does not automatically upgrade the Blue node group.

## Blue/Green Upgrade

Initial state:

EKS Control Plane 1.32
        |
        +---- Blue Nodes 1.32

Step 1: Upgrade the EKS control plane from 1.32 to 1.33.

After the control plane upgrade:

EKS Control Plane 1.33
        |
        +---- Blue Nodes 1.32

Step 2: Create the Green node group with Kubernetes 1.33.

EKS Control Plane 1.33
        |
        +---- Blue Nodes 1.32
        |
        +---- Green Nodes 1.33

Step 3: Verify Green nodes.

`kubectl get nodes -o wide`

Verify that the Green nodes are Ready and running Kubernetes 1.33.

Step 4: Cordon Blue nodes.

`kubectl cordon <BLUE_NODE>`

Cordon prevents new workloads from being scheduled on the Blue node.

Step 5: Drain Blue nodes.

`kubectl drain <BLUE_NODE> --ignore-daemonsets --delete-emptydir-data`

Drain the Blue nodes one at a time.

Step 6: Verify workloads.

`kubectl get nodes -o wide`

`kubectl get pods -A -o wide`

Verify that application workloads are running successfully on Green nodes.

Step 7: Remove the Blue node group using Terraform after Green and the workloads have been verified.

Final state:

EKS Control Plane 1.33
        |
        +---- Green Nodes 1.33

Blue nodes are removed.

## Cluster Autoscaler

Cluster Autoscaler automatically adjusts the number of worker nodes based on workload requirements.

This project uses a dedicated IAM role for Cluster Autoscaler through IRSA.

The authentication flow is:

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

Cluster Autoscaler Service Account:

`kube-system/cluster-autoscaler`

The IAM role is attached using the annotation:

`eks.amazonaws.com/role-arn`

## Cluster Autoscaler Permissions

The Cluster Autoscaler IAM policy contains permissions for reading Auto Scaling and EC2 information:

- autoscaling:DescribeAutoScalingGroups
- autoscaling:DescribeAutoScalingInstances
- autoscaling:DescribeLaunchConfigurations
- autoscaling:DescribeScalingActivities
- autoscaling:DescribeTags
- ec2:DescribeImages
- ec2:DescribeInstanceTypes
- ec2:DescribeLaunchTemplateVersions

It also has permissions to change Auto Scaling capacity:

- autoscaling:SetDesiredCapacity
- autoscaling:TerminateInstanceInAutoScalingGroup
- autoscaling:UpdateAutoScalingGroup

## Terraform Commands

Initialize Terraform:

`terraform init`

Format Terraform files:

`terraform fmt`

Validate the configuration:

`terraform validate`

Create a plan:

`terraform plan`

Apply the configuration:

`terraform apply`

Check Terraform state:

`terraform state list`

Refresh the Terraform state:

`terraform plan -refresh-only`

Destroy the resources:

`terraform destroy`

## Kubernetes Verification

Check nodes:

`kubectl get nodes -o wide`

Check all pods:

`kubectl get pods -A`

Check Cluster Autoscaler:

`kubectl get pods -n kube-system`

Check Cluster Autoscaler logs:

`kubectl logs -n kube-system deployment/cluster-autoscaler`

Check the Cluster Autoscaler Service Account:

`kubectl get sa cluster-autoscaler -n kube-system -o yaml`

Check the IAM role annotation:

`kubectl get sa cluster-autoscaler -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'`

## Important Rules

Do not directly upgrade the Blue managed node group during the Blue/Green migration.

Do not delete Blue before Green is verified.

Do not use `kubectl drain --force` unless absolutely necessary.

The preferred migration process is:

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
Verify workloads
    |
    v
Delete Blue

## Final Objective

The final environment should have:

- EKS control plane: 1.33
- Green node group: 1.33
- Blue node group: Removed
- Applications: Healthy
- Workloads: Running on Green nodes
