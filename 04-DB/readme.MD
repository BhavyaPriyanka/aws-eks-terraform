# 04-DB — Amazon RDS MySQL

## 1. Purpose

This Terraform module provisions a managed MySQL database for the Localhelp application using Amazon RDS. It connects the database to the VPC networking and security groups created by the previous modules.

## 2. RDS Instance Configuration

The `terraform-aws-modules/rds/aws` module creates the database instance with these settings:

- Identifier: `localhelp-dev`
- Engine: MySQL 8.0
- Instance type: `db.t3.micro`
- Storage: 5 GB
- Database name: `appdb`
- Port: `3306`
- Parameter group family: `mysql8.0`

The application uses `appdb` as its database schema to store Localhelp application data.

## 3. Networking and Security

The module retrieves `db_sg_id` and `db_subnet_group_name` from AWS Systems Manager Parameter Store. The security group controls which resources can connect to MySQL, while the DB subnet group determines which subnets RDS can use. Based on the previous security-group configuration, access is permitted from the EKS nodes, bastion host, and Jenkins agent security group on port `3306`.

## 4. Database Credentials

`manage_master_user_password = true` instructs the RDS module to manage the master password through AWS Secrets Manager. This avoids hardcoding the database password directly in Terraform configuration. The master username is configured as `root`; for production, use a dedicated database administrator account and a separate least-privilege account for the application.

## 5. Database Parameters and Options

The `parameters` block configures `character_set_client` and `character_set_server` as `utf8mb4`, enabling support for a broad range of Unicode characters. The `options` block attempts to configure a MariaDB audit plugin, but this option must be verified for compatibility with the selected MySQL engine and RDS option-group support before applying the configuration.

## 6. Backup and Deletion Protection

`skip_final_snapshot = false` requires a final snapshot when Terraform deletes the RDS instance, and `final_snapshot_identifier` sets its name to `localhelp-dev-final`. This preserves a final database backup during deletion, but it does not by itself enable automated backups or prevent accidental deletion.

## 7. Route 53 DNS Record

The `aws_route53_record.db` resource creates a CNAME record named `db-dev.localhelp.store` in the `localhelp.store` hosted zone. It points to `module.db.db_instance_address`, allowing the Localhelp backend to connect through a stable DNS name instead of using the AWS-generated RDS endpoint directly.

The `depends_on` declaration ensures Terraform creates the RDS module before creating the DNS record.

## 8. SSM and Route 53 Data Sources

- `data.aws_ssm_parameter.db_sg_id` retrieves the database security group ID.
- `data.aws_ssm_parameter.db_subnet_group_name` retrieves the database subnet group name.
- `data.aws_route53_zone.main` retrieves the existing `localhelp.store` hosted zone.

These data sources allow the DB module to reuse resources created by earlier infrastructure modules instead of hardcoding their IDs.

## 9. End-to-End Integration

VPC module creates the network and DB subnet group → 02-SG creates the database security group → SSM Parameter Store exposes their identifiers → 04-DB provisions RDS MySQL → Route 53 creates `db-dev.localhelp.store` → Localhelp backend connects to the database using its DNS name and credentials.
