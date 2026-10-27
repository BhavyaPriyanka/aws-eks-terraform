# 01-VPC — Terraform Module README

## 1. Purpose

The `01-VPC` module creates the networking foundation for the Localhelp application in AWS. It creates one VPC (`10.0.0.0/16`), two public subnets, two private subnets, two database subnets across two Availability Zones, an Internet Gateway, a NAT Gateway, route tables, and an RDS DB subnet group.

## 2. How the code integrates

### Root module — calls the reusable VPC module

The `module "vpc"` block downloads the reusable module from GitHub and passes project details, subnet CIDRs, tags, and the peering flag. The root module then uses the child module's outputs to publish networking IDs to AWS Systems Manager Parameter Store.

### VPC and subnets — create the network

- VPC: `aws_vpc.main` creates the isolated network with CIDR `10.0.0.0/16`.
- Public subnets: `aws_subnet.public` creates `10.0.1.0/24` and `10.0.2.0/24`. These are suitable for internet-facing resources such as an Application Load Balancer.
- Private subnets: `aws_subnet.private` creates `10.0.11.0/24` and `10.0.12.0/24`. These are intended for EKS worker nodes and application workloads.
- Database subnets: `aws_subnet.database` creates `10.0.21.0/24` and `10.0.22.0/24`. These provide subnet placement for RDS.
- Availability Zones: `data.aws_availability_zones.zones` retrieves available AZs, and `local.az_names` selects the first two.

### Internet Gateway and NAT Gateway — provide connectivity

- Internet Gateway: `aws_internet_gateway.gw` attaches an IGW to the VPC.
- Elastic IP: `aws_eip.nat` allocates a public IP for the NAT Gateway.
- NAT Gateway: `aws_nat_gateway.nat` is placed in the first public subnet and allows private resources to initiate outbound internet connections without requiring public IPs.

### Route tables — control traffic flow

- Public route table: Routes internet-bound traffic (`0.0.0.0/0`) through the Internet Gateway.
- Private route table: Routes internet-bound traffic through the NAT Gateway.
- Database route table: Also routes internet-bound traffic through the NAT Gateway.
- Route table associations: Associate each subnet with its corresponding route table.

### DB subnet group — connects networking to RDS

`aws_db_subnet_group.default` groups the database subnet IDs. The RDS module can use this group to place the database in the designated database subnets.

### Data sources and outputs — retrieve and expose values

The data sources retrieve available AZs and details about the default VPC and its main route table. The module outputs expose the VPC ID, subnet IDs, and DB subnet group ID/name for other Terraform modules to consume.

### SSM Parameter Store — shares IDs with other modules

The root module stores the VPC ID, public subnet IDs, private subnet IDs, and DB subnet group name in SSM under paths such as `/localhelp/dev/vpc_id`. Other modules can retrieve these values instead of hardcoding IDs.

## 3. Important configuration issues to fix

1. Subnet association counts: All three route table associations use `length(var.private_subnet_cidrs)`. Use the matching list for each type: public, private, or database. The current configuration works only when the counts align.
2. Database routing: The database route table sends `0.0.0.0/0` through the NAT Gateway. If your RDS databases do not need outbound internet access, consider removing that default route.
3. NAT availability: One NAT Gateway serves both AZs. This saves cost, but a failure or outage in its AZ can affect outbound connectivity from private subnets in both AZs.
4. VPC peering: `is_peering_required` is passed to the module, but the provided code does not show any `aws_vpc_peering_connection` resource or conditional peering logic. The variable alone does not create peering.
5. SSM parameter types: `StringList` is appropriate for comma-separated subnet IDs. Confirm the consuming modules split or parse the returned value as needed.
6. Git source version: `?ref=main` tracks the main branch. Pin a release tag or commit SHA for reproducible deployments.

## 4. Network layout

| Resource         | CIDR / configuration           | Purpose                               |
| ---------------- | ------------------------------ | ------------------------------------- |
| VPC              | `10.0.0.0/16`                  | Main network                          |
| Public subnets   | `10.0.1.0/24`, `10.0.2.0/24`   | Internet-facing resources             |
| Private subnets  | `10.0.11.0/24`, `10.0.12.0/24` | EKS nodes and applications            |
| Database subnets | `10.0.21.0/24`, `10.0.22.0/24` | RDS placement                         |
| Internet Gateway | Attached to VPC                | Public internet routing               |
| NAT Gateway      | First public subnet            | Outbound access for private resources |

End-to-end flow: Root Terraform module → reusable VPC module → AWS networking resources → module outputs → SSM Parameter Store → other Terraform modules.
