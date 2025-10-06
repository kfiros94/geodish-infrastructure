# modules/vpc/main.tf

# Local values for consistent naming and tags
locals {
  common_tags = merge(var.tags, {
    Module      = "vpc"
    Project     = var.project_name
    Environment = var.environment
  })
  
  name_prefix = "${var.project_name}-${var.environment}"
}

#==========================================
# VPC Core Resources
#==========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    # EKS-specific tags for cluster discovery
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
  })
}

#==========================================
# Internet Gateway (Required for Public Subnets)
#==========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

#==========================================
# Public Subnets (For NAT Gateways and Load Balancers)
#==========================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "Public"
    # EKS tags for public subnet identification
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
    "kubernetes.io/role/elb"                         = "1"
  })
}

#==========================================
# PRIVATE SUBNETS - Core Security Implementation
# These subnets have NO direct internet access
# EKS worker nodes will be deployed here for security
#==========================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # IMPORTANT: Do NOT map public IPs - this keeps nodes private
  map_public_ip_on_launch = false
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "Private"
    # EKS-specific tags for private subnet identification
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "shared"
    "kubernetes.io/role/internal-elb"                = "1"
    # Security classification
    "Security" = "Private"
    "Purpose"  = "EKS-WorkerNodes"
  })
}

#==========================================
# Elastic IPs for NAT Gateways
#==========================================

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  
  domain = "vpc"
  
  # Ensure proper cleanup order
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

#==========================================
# NAT Gateways (Enable Private Subnet Internet Access)
# Critical for EKS nodes to pull images and communicate
#==========================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

#==========================================
# Route Table for Public Subnets
#==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "Public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#==========================================
# Route Tables for Private Subnets
# SECURITY: Routes through NAT Gateway, not Internet Gateway
#==========================================

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : length(var.private_subnet_cidrs)
  
  vpc_id = aws_vpc.main.id
  
  # Only add NAT gateway route if NAT is enabled
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }
  
  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-private-rt-${count.index + 1}"
    Type     = "Private"
    Security = "High"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#==========================================
# VPC Flow Logs (Security & Monitoring)
#==========================================

resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/flow-logs/${local.name_prefix}"
  retention_in_days = 14
  
  tags = local.common_tags
}

resource "aws_iam_role" "flow_log" {
  name = "${local.name_prefix}-vpc-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${local.name_prefix}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
