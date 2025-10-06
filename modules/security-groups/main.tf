# modules/security-groups/main.tf

# Local values for consistent naming and tags
locals {
  common_tags = merge(var.tags, {
    Module      = "security-groups"
    Project     = var.project_name
    Environment = var.environment
  })
  
  name_prefix = "${var.project_name}-${var.environment}"
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${local.name_prefix}-eks"
}

#==========================================
# EKS CLUSTER SECURITY GROUP
# Controls access to the EKS control plane
#==========================================

resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS cluster security group - controls access to control plane"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-cluster-sg"
    Type = "EKS-Cluster"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  })
}

# HTTPS access to EKS API server from worker nodes
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow HTTPS communication from worker nodes to cluster API"
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.cluster.id
}

# Allow all outbound traffic from cluster
resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow all outbound traffic from EKS cluster"
  type              = "egress"
  from_port        = 0
  to_port          = 65535
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# Optional: Allow external access to cluster API
resource "aws_security_group_rule" "cluster_ingress_external" {
  count = length(var.cluster_endpoint_public_access_cidrs) > 0 && var.cluster_endpoint_public_access ? 1 : 0
  
  description       = "Allow external access to EKS cluster API"
  type              = "ingress"
  from_port        = 443
  to_port          = 443
  protocol         = "tcp"
  cidr_blocks      = var.cluster_endpoint_public_access_cidrs
  security_group_id = aws_security_group.cluster.id
}

#==========================================
# EKS NODE GROUP SECURITY GROUP
# Controls traffic to/from worker nodes
#==========================================

resource "aws_security_group" "node_group" {
  name        = "${local.name_prefix}-eks-nodes-sg"
  description = "EKS node group security group - controls traffic to worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-nodes-sg"
    Type = "EKS-Nodes"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  })
}

# Node to node communication on all ports
resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port               = 0
  to_port                 = 65535
  protocol                = "-1"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.node_group.id
}

# Allow cluster control plane to communicate with nodes
resource "aws_security_group_rule" "node_ingress_cluster_control_plane" {
  description              = "Allow EKS control plane to communicate with nodes"
  type                     = "ingress"
  from_port               = 1025
  to_port                 = 65535
  protocol                = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id       = aws_security_group.node_group.id
}

# Allow cluster control plane to communicate with nodes on HTTPS (webhook)
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  description              = "Allow EKS control plane HTTPS webhook communication"
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id       = aws_security_group.node_group.id
}

# Allow all outbound traffic from nodes
resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow all outbound traffic from worker nodes"
  type              = "egress"
  from_port        = 0
  to_port          = 65535
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group.id
}

#==========================================
# APPLICATION LOAD BALANCER SECURITY GROUP
# Controls traffic to ALB (public-facing)
#==========================================

resource "aws_security_group" "alb" {
  count = var.enable_alb_ingress ? 1 : 0
  
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
    Type = "ALB"
    Purpose = "LoadBalancer"
  })
}

# Dynamic ALB ingress rules
resource "aws_security_group_rule" "alb_ingress" {
  count = var.enable_alb_ingress ? length(var.alb_security_group_rules) : 0
  
  type              = var.alb_security_group_rules[count.index].type
  from_port         = var.alb_security_group_rules[count.index].from_port
  to_port           = var.alb_security_group_rules[count.index].to_port
  protocol          = var.alb_security_group_rules[count.index].protocol
  cidr_blocks       = var.alb_security_group_rules[count.index].cidr_blocks
  description       = var.alb_security_group_rules[count.index].description
  security_group_id = aws_security_group.alb[0].id
}

# ALB to node communication for health checks and traffic
resource "aws_security_group_rule" "alb_to_nodes" {
  count = var.enable_alb_ingress ? 1 : 0
  
  description              = "Allow ALB to communicate with worker nodes"
  type                     = "egress"
  from_port               = var.app_port
  to_port                 = var.app_port
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.alb[0].id
}

# Allow nodes to receive traffic from ALB
resource "aws_security_group_rule" "nodes_from_alb" {
  count = var.enable_alb_ingress ? 1 : 0
  
  description              = "Allow worker nodes to receive traffic from ALB"
  type                     = "ingress"
  from_port               = var.app_port
  to_port                 = var.app_port
  protocol                = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id       = aws_security_group.node_group.id
}

#==========================================
# DATABASE SECURITY GROUP (MongoDB)
# Controls access to MongoDB instances
#==========================================

resource "aws_security_group" "database" {
  name        = "${local.name_prefix}-mongodb-sg"
  description = "Security group for MongoDB database"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mongodb-sg"
    Type = "Database"
    Database = "MongoDB"
  })
}

# Allow MongoDB access from application nodes only
resource "aws_security_group_rule" "database_ingress_from_nodes" {
  description              = "Allow MongoDB access from EKS nodes"
  type                     = "ingress"
  from_port               = var.mongodb_port
  to_port                 = var.mongodb_port
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.database.id
}

# MongoDB internal communication (replica sets)
resource "aws_security_group_rule" "database_ingress_self" {
  description              = "Allow MongoDB instances to communicate with each other"
  type                     = "ingress"
  from_port               = var.mongodb_port
  to_port                 = var.mongodb_port
  protocol                = "tcp"
  source_security_group_id = aws_security_group.database.id
  security_group_id       = aws_security_group.database.id
}

# Allow outbound traffic for MongoDB (updates, etc.)
resource "aws_security_group_rule" "database_egress_all" {
  description       = "Allow outbound traffic from MongoDB"
  type              = "egress"
  from_port        = 0
  to_port          = 65535
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.database.id
}

#==========================================
# ADDITIONAL SECURITY GROUPS
# For specific application components
#==========================================

# Redis/Cache security group (if needed later)
resource "aws_security_group" "cache" {
  name        = "${local.name_prefix}-cache-sg"
  description = "Security group for cache layer (Redis/ElastiCache)"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cache-sg"
    Type = "Cache"
    Purpose = "Caching"
  })
}

resource "aws_security_group_rule" "cache_ingress_from_nodes" {
  description              = "Allow cache access from EKS nodes"
  type                     = "ingress"
  from_port               = 6379
  to_port                 = 6379
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.cache.id
}

#==========================================
# BASTION HOST SECURITY GROUP (Optional)
# For secure SSH access to private resources
#==========================================

resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-bastion-sg"
    Type = "Bastion"
    Purpose = "SecureAccess"
  })
}

# SSH access from allowed CIDR blocks
resource "aws_security_group_rule" "bastion_ssh" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  
  description       = "Allow SSH access to bastion host"
  type              = "ingress"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  cidr_blocks      = var.allowed_cidr_blocks
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_egress" {
  description       = "Allow outbound traffic from bastion"
  type              = "egress"
  from_port        = 0
  to_port          = 65535
  protocol         = "-1"
  cidr_blocks      = [var.vpc_cidr]
  security_group_id = aws_security_group.bastion.id
}

#==========================================
# VPC ENDPOINTS SECURITY GROUP
# For AWS service communication without internet
#==========================================

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
    Type = "VPCEndpoints"
    Purpose = "AWSServices"
  })
}

# Allow HTTPS from nodes to VPC endpoints
resource "aws_security_group_rule" "vpc_endpoints_ingress" {
  description              = "Allow HTTPS from nodes to VPC endpoints"
  type                     = "ingress"
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id       = aws_security_group.vpc_endpoints.id
}
