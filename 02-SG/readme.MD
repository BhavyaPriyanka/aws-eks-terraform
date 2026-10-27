# 02-SG — Security Groups README

## 1. Purpose

This module creates security groups for Localhelp's database, EKS control plane, EKS worker nodes, ingress ALB, bastion host, and VPN. It uses a reusable security-group module from GitHub and adds ingress rules to control which resources can communicate with each other.

# Reusable Security Group Module
This resource creates a reusable AWS security group using the provided VPC ID, name, and description. The dynamic "ingress" block generates inbound rules from var.inbound_rules, while dynamic "egress" generates outbound rules from var.outbound_rules; each rule defines source/destination ports, protocol, and CIDR blocks. The merge() function combines common tags, security-group-specific tags, and a standard resource name. This module is called by 02-SG for the DB, EKS cluster, worker nodes, ingress, bastion, and VPN security groups, avoiding duplicated resource definitions. Note: The rules shown support CIDR-based access only; they do not handle source_security_group_id rules used in your 02-SG configuration, so check whether those rules are created separately or supported elsewhere in the module.

## 2. Security Groups

- DB: Allows MySQL connections on port `3306` from the bastion, EKS nodes, and Jenkins agent security group.
- Ingress: Allows public HTTP (`80`) and HTTPS (`443`) traffic to reach the ingress ALB.
- Cluster: Allows HTTPS (`443`) access from the bastion to the EKS control plane, plus traffic from the node security group.
- Node: Allows traffic from the EKS control plane, other resources within the VPC CIDR (`10.0.0.0/16`), and the ingress security group on NodePort range `30000–32768`.
- Bastion: Allows SSH (`22`) from `0.0.0.0/0`, meaning any IPv4 address can attempt to connect.
- VPN: Creates a security group using custom ingress rules supplied through `var.vpn_sg_rules`.

## 3. How the rules work

The `aws_security_group_rule` resources define which inbound connections are permitted. For example, `db_node` allows MySQL traffic from EKS nodes to RDS, while `db_bastion` allows database access from the bastion. The `cluster_bastion` rule allows the bastion to reach the EKS API on port `443`. The `node_ingress` rule allows traffic from the ingress ALB security group to the EKS nodes on the specified NodePort range.

## 4. SSM Parameter Store integration

The module retrieves the VPC ID from `/localhelp/dev/vpc_id` and the Jenkins tools security-group ID from `/localhelp/dev/tools_sg_id`. It then stores the created security-group IDs in SSM, including `db_sg_id`, `bastion_sg_id`, `vpn_sg_id`, `cluster_sg_id`, `node_sg_id`, and `ingress_sg_id`. Other Terraform modules can retrieve these values without hardcoding security-group IDs.

## 5. End-to-end integration

VPC module → SSM stores VPC ID → Security-group module creates groups → Ingress rules permit required communication → SSM stores security-group IDs → EKS, RDS, and other modules consume those IDs.

## 6. Important security observations

- Bastion SSH: `0.0.0.0/0` exposes port `22` to the internet. Restrict this to your trusted public IP or VPN CIDR.
- EKS control-plane rules: Allowing all protocols and ports between cluster and node security groups is broad. Review these rules against EKS networking requirements.
- Node VPC rule: Allowing all protocols and ports from the entire VPC CIDR is permissive. Narrow it where possible.
- NodePort range: The configured range is `30000–32768`; the common Kubernetes default is `30000–32767`. Confirm your actual service configuration.
- Outbound rules: The code shown defines ingress rules, but the reusable module's egress behavior must be checked separately.
- VPN and peering: The VPN security group accepts custom ingress rules, but this code alone does not create a VPN connection or VPC peering connection.
