# modules/vpc/outputs.tf

#==========================================
# VPC Core Outputs
#==========================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

#==========================================
# Public Subnet Outputs
#==========================================

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_arns" {
  description = "ARNs of the public subnets"
  value       = aws_subnet.public[*].arn
}

#==========================================
# Private Subnet Outputs (Critical for EKS)
#==========================================

output "private_subnet_ids" {
  description = "IDs of the private subnets - where EKS nodes will be deployed"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_arns" {
  description = "ARNs of the private subnets"
  value       = aws_subnet.private[*].arn
}

output "private_subnet_availability_zones" {
  description = "Availability zones of the private subnets"
  value       = aws_subnet.private[*].availability_zone
}

#==========================================
# Availability Zone Outputs
#==========================================

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

output "azs_count" {
  description = "Number of availability zones"
  value       = length(var.availability_zones)
}

#==========================================
# Gateway and Routing Outputs
#==========================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

#==========================================
# Route Table Outputs
#==========================================

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

#==========================================
# Security and Monitoring Outputs
#==========================================

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = aws_flow_log.vpc_flow_log.id
}

output "vpc_flow_log_cloudwatch_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_log.name
}

#==========================================
# EKS-Specific Outputs
#==========================================

output "eks_cluster_subnet_ids" {
  description = "Subnet IDs for EKS cluster (both public and private)"
  value       = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
}

output "eks_node_group_subnet_ids" {
  description = "Private subnet IDs for EKS node groups (security best practice)"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_security_group_additional_rules" {
  description = "VPC CIDR for EKS security group rules"
  value = {
    vpc_cidr = aws_vpc.main.cidr_block
  }
}

#==========================================
# Load Balancer Outputs
#==========================================

output "public_subnets_for_alb" {
  description = "Public subnet IDs for Application Load Balancer"
  value       = aws_subnet.public[*].id
}

output "private_subnets_for_nlb" {
  description = "Private subnet IDs for Network Load Balancer"
  value       = aws_subnet.private[*].id
}

#==========================================
# Tagging Outputs
#==========================================

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

output "name_prefix" {
  description = "Name prefix used for resource naming"
  value       = local.name_prefix
}

#==========================================
# Summary Output for Easy Reference
#==========================================

output "vpc_summary" {
  description = "Summary of VPC configuration"
  value = {
    vpc_id                 = aws_vpc.main.id
    vpc_cidr              = aws_vpc.main.cidr_block
    private_subnet_ids    = aws_subnet.private[*].id
    public_subnet_ids     = aws_subnet.public[*].id
    availability_zones    = var.availability_zones
    nat_gateways_enabled  = var.enable_nat_gateway
    single_nat_gateway    = var.single_nat_gateway
    environment           = var.environment
  }
}
