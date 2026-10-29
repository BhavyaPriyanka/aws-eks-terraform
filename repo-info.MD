

# LocalHelp — AWS EKS Terraform Infrastructure

Infrastructure as Code for deploying and managing the LocalHelp application platform on AWS using Terraform, Amazon EKS, managed node groups, Amazon RDS, Amazon ECR, Helm, and Argo CD.

This repository provisions the cloud infrastructure required to support a containerized application with separate frontend and backend workloads, database connectivity, ingress, monitoring, and GitOps-based delivery.

## Architecture Overview

```text
                         Developer
                             |
                         GitHub
                             |
                     Jenkins CI/CD
                             |
                       Amazon ECR
                             |
                       GitOps Repo
                             |
                          Argo CD
                             |
                    Amazon EKS Cluster
                       localhelp-dev
                             |
              +--------------+--------------+
              |                             |
        Frontend Workloads            Backend Workloads
              |                             |
              +--------------+--------------+
                             |
                       Amazon RDS
                         MySQL

AWS Infrastructure managed using Terraform:
VPC | Subnets | Security Groups | IAM | EKS | ECR
RDS | ACM | Load Balancing | Monitoring | Argo CD
```

## Technology Stack

| Category | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| Container Orchestration | Amazon EKS |
| Container Registry | Amazon ECR |
| Database | Amazon RDS for MySQL |
| Networking | Amazon VPC, Subnets, Security Groups |
| Kubernetes Packaging | Helm |
| GitOps | Argo CD |
| Load Balancing | AWS Elastic Load Balancing |
| TLS Certificates | AWS Certificate Manager |
| Monitoring | Prometheus, Grafana, Alertmanager |
| Persistent Storage | Amazon EBS, EBS CSI Driver |
| Remote State | Amazon S3 |
| State Locking | DynamoDB, where configured |

## Repository Structure

The repository is organized into numbered Terraform layers to separate infrastructure responsibilities and make dependencies easier to manage.

```text
aws-eks-terraform/
├── bootstrap/
├── 01-VPC/
├── 02-SG/
├── 03-BASTION/
├── 04-DB/
├── 05-EKS/
├── 06-ACM/
├── 07-INGRESS-ALB/
├── 08-ECR/
├── 09-MONITORING/
└── 10-ARGOCD/
```

> The exact files and resources inside each directory should be verified against the current repository.

### Module Responsibilities

| Directory | Responsibility |
|---|---|
| `bootstrap/` | Initial setup required before using the remote Terraform backend, where configured |
| `01-VPC/` | VPC, subnet and networking foundation |
| `02-SG/` | Security groups and traffic rules |
| `03-BASTION/` | Bastion host infrastructure for authorized administrative access |
| `04-DB/` | Amazon RDS MySQL database infrastructure |
| `05-EKS/` | EKS cluster, managed node groups, IAM integration, add-ons and cluster components |
| `06-ACM/` | TLS certificate resources |
| `07-INGRESS-ALB/` | Ingress and application load-balancing resources |
| `08-ECR/` | Container repositories for application images |
| `09-MONITORING/` | Kubernetes monitoring components and persistent storage configuration |
| `10-ARGOCD/` | Argo CD installation and GitOps-related Kubernetes resources, where configured |

## AWS Environment

The following values are the project configuration recorded for this environment.

| Setting | Value |
|---|---|
| AWS Region | `us-east-1` |
| Project | `localhelp` |
| Environment | `dev` |
| EKS Cluster | `localhelp-dev` |
| Kubernetes Version | `1.32` in the recorded EKS configuration |
| VPC Environment | LocalHelp development environment |
| Database Engine | MySQL 8.0 |
| Application Database | `appdb` |
| Remote State Bucket | `localhelp-remote-tfstate` |
| Remote State Key | `localhelp-dev-eks` |
| State Lock Table | `localhelp-locking`, where configured |

Verify the current Terraform variables and AWS resources before using these values for a new deployment.

## Infrastructure Details

### 1. Networking

The networking layer provides the foundation for the remaining infrastructure.

It is responsible for the VPC, subnet layout and network resources consumed by the EKS, database and administrative-access layers.

Downstream layers have previously consumed network configuration through AWS Systems Manager Parameter Store, including:

```text
/localhelp/dev/vpc_id
/localhelp/dev/cluster_sg_id
/localhelp/dev/node_sg_id
/localhelp/dev/private_subnet_ids
```

These parameters must exist and contain the expected values before dependent layers are applied.

### 2. Amazon EKS

The EKS layer provisions the Kubernetes control plane and managed worker node groups.

Recorded configuration includes:

- Cluster name: `localhelp-dev`
- Kubernetes version: `1.32`
- Public Kubernetes API endpoint enabled
- Authentication mode: `API_AND_CONFIG_MAP`
- Private subnets used for cluster and node networking
- Managed node groups for frontend, backend and other workloads
- EKS access entries for authorized administrative access
- Core Kubernetes networking and DNS add-ons
- EBS CSI Driver integration for persistent storage

The managed node groups have used Spot capacity and `t3.small` instances in the recorded configuration. Confirm the current Terraform files for the exact scaling settings and instance types.

### 3. IAM and Cluster Access

IAM permissions control access to AWS resources and the Kubernetes cluster.

The EKS configuration includes an access entry for the bastion IAM role and an associated EKS cluster access policy.

The EKS layer has also included IAM Roles for Service Accounts (IRSA) for Kubernetes components such as the Cluster Autoscaler and AWS Load Balancer Controller.

These integrations allow supported Kubernetes service accounts to obtain AWS permissions through their associated IAM roles rather than relying on static AWS credentials inside workloads.

### 4. Amazon RDS

The database layer provides MySQL persistence for the application.

Recorded configuration:

- RDS instance identifier: `localhelp-dev`
- Engine: MySQL 8.0
- Database name: `appdb`
- Port: `3306`

Database connectivity should be restricted through security-group rules and the intended application or administrative access paths. Database credentials should be stored and retrieved through an approved secrets-management mechanism, not committed to Git.

### 5. Amazon ECR

Amazon ECR stores the container images produced by the CI pipelines.

The application repositories used by LocalHelp include:

```text
localhelp-backend
localhelp-frontend
```

The expected image naming pattern is:

```text
<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/<REPOSITORY>:<IMAGE_TAG>
```

The CI pipelines build and push images to ECR. The GitOps repository records the desired application image versions for Argo CD to reconcile.

### 6. Ingress and Load Balancing

The ingress layer connects external application traffic to the Kubernetes workloads through AWS load-balancing resources.

The project has included AWS Load Balancer Controller IAM integration and Helm-based controller configuration. Confirm the current ingress implementation and controller installation before assuming all resources are active.

AWS Certificate Manager is used for TLS certificate resources where configured.

### 7. Monitoring and Storage

The monitoring layer has included the `kube-prometheus-stack` Helm release and a dedicated Kubernetes namespace.

The intended monitoring components are:

- Prometheus — metrics collection and querying
- Grafana — dashboards and visualization
- Alertmanager — alert routing and management

The configuration has also included a `gp3` Kubernetes StorageClass with encrypted EBS volumes, the EBS CSI Driver, and `WaitForFirstConsumer` volume binding.

## Terraform Remote State

The project has recorded the following remote state configuration:

```hcl
bucket         = "localhelp-remote-tfstate"
key            = "localhelp-dev-eks"
region         = "us-east-1"
dynamodb_table = "localhelp-locking"
```

Use the backend configuration actually present in the relevant Terraform layer. If different layers use separate state keys, preserve those individual keys rather than sharing one state file unintentionally.

Remote state allows Terraform to track managed infrastructure across runs. State locking, where configured, helps prevent concurrent state modifications.

Never commit Terraform state files, state backups, private keys, passwords, or other secrets to Git.

## Prerequisites

Before deploying the infrastructure, install and configure:

- AWS CLI
- Terraform
- Git
- AWS credentials or an approved IAM role
- kubectl for Kubernetes administration
- Helm for Helm-based resources

The AWS identity used for deployment must have the permissions required by the resources managed in the relevant Terraform layer.

Check your installed tools:

```bash
terraform version
aws --version
kubectl version --client
helm version
```

Verify the AWS identity and region:

```bash
aws sts get-caller-identity
aws configure get region
```

## Deployment Workflow

Deploy the infrastructure in dependency order. The sequence below is a starting point; follow the actual dependencies and backend configuration in the repository.

### Step 1: Clone the Repository

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/aws-eks-terraform.git
cd aws-eks-terraform
```

Replace the repository URL with the actual GitHub URL.

### Step 2: Initialize the Required Backend

If the repository uses a bootstrap layer to create the remote state bucket or locking resources, initialize and apply that layer first.

```bash
cd bootstrap
terraform init
terraform validate
terraform plan
```

Review the plan before applying it.

### Step 3: Initialize and Validate a Terraform Layer

For example, the VPC layer:

```bash
cd ../01-VPC

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Apply only after reviewing the plan and confirming the target account, region and resource changes.

```bash
terraform apply
```

### Step 4: Deploy Dependent Layers

Continue with the relevant layers in dependency order:

```text
01-VPC
   ↓
02-SG
   ↓
03-BASTION and 04-DB
   ↓
05-EKS
   ↓
06-ACM / 07-INGRESS-ALB / 08-ECR
   ↓
09-MONITORING / 10-ARGOCD
```

This diagram is a high-level guide, not a substitute for the dependencies defined in the Terraform configuration. Some layers may be independent or require a different order.

For each layer, use the same review process:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Review the plan before running `terraform apply`.

## Verify the EKS Cluster

After the EKS layer has been deployed, verify cluster status:

```bash
aws eks describe-cluster \
  --name localhelp-dev \
  --region us-east-1 \
  --query 'cluster.status' \
  --output text
```

Configure `kubectl`:

```bash
aws eks update-kubeconfig \
  --name localhelp-dev \
  --region us-east-1
```

Check cluster connectivity and nodes:

```bash
kubectl get nodes
kubectl get namespaces
kubectl get pods -A
```

Check monitoring and GitOps components, if installed:

```bash
kubectl get pods -n monitoring
kubectl get pods -n argocd
```

These commands verify the current environment; they do not guarantee that every application or integration is healthy.

## GitOps and Application Delivery

The Terraform repository provides infrastructure for the LocalHelp platform. Application build and release automation is maintained separately.

The intended delivery flow is:

1. Jenkins CI checks out application code, runs build and quality checks, and builds container images.
2. CI pushes the versioned images to Amazon ECR.
3. The Jenkins CD pipeline updates the corresponding Helm values in the `Gitops-ArgoCD` repository.
4. Argo CD detects the desired-state changes and reconciles the Kubernetes resources.
5. The frontend and backend workloads run on EKS and connect to the MySQL database.

The Jenkins CD pipelines update GitOps configuration; they do not directly deploy workloads with `kubectl` or `helm upgrade`.

## Terraform Maintenance

Before making infrastructure changes:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

Review the plan carefully, particularly for:

- EKS cluster or node-group replacements
- VPC and subnet changes
- Security-group ingress or egress changes
- RDS modifications or deletion
- Remote-state backend changes
- IAM policy and access-entry changes
- Helm release upgrades or removals
- Persistent-volume and storage changes

Do not apply a stale plan or run `terraform destroy` without confirming the intended infrastructure scope and reviewing the current plan.

## Security Considerations

- Use least-privilege IAM roles and policies.
- Avoid embedding AWS credentials in Terraform files or container images.
- Keep database access restricted to approved security groups.
- Protect the Terraform remote state bucket and enable appropriate encryption and access controls.
- Restrict public access to administrative endpoints.
- Store secrets in AWS Secrets Manager or another approved secret-management system.
- Review Kubernetes API endpoint exposure and EKS access policies.
- Review security-group rules and TLS configuration before production use.
- Treat this development configuration as a starting point, not a production security certification.

## Cleanup

Destroying infrastructure can cause downtime and permanent data loss.

Before cleanup, inspect the resources managed by the specific Terraform state:

```bash
terraform plan -destroy
```

Only proceed if the planned deletions match the intended scope and the necessary data has been backed up. Destroy dependent resources in the appropriate order, and preserve shared state infrastructure until it is no longer needed.

## Project Goal

This project demonstrates hands-on AWS DevOps implementation using Terraform, EKS, container registries, IAM, managed database services, Kubernetes monitoring and GitOps-based application delivery.

It is intended to support practical learning and demonstrate infrastructure provisioning, dependency management, cloud networking, cluster administration, automation and operational troubleshooting.

---

**Important:** This README describes the recorded LocalHelp design. Confirm the current repository configuration and live AWS resources before treating every component as deployed or healthy.
