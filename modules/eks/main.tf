# modules/eks/main.tf

# Local values for consistent naming and tags
locals {
  common_tags = merge(var.tags, {
    Module      = "eks"
    Project     = var.project_name
    Environment = var.environment
  })
  
  name_prefix = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

#==========================================
# CLOUDWATCH LOG GROUP for EKS Cluster Logs
#==========================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-logs"
    Type = "EKS-Cluster-Logs"
  })
}

#==========================================
# EKS CLUSTER
# The main Kubernetes control plane
#==========================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_service_role_arn
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = var.cluster_security_group_ids
  }
  
  # Enable cluster logging for monitoring and security
  enabled_cluster_log_types = var.cluster_enabled_log_types
  
  # Ensure CloudWatch log group exists before cluster
  depends_on = [
    aws_cloudwatch_log_group.cluster
  ]
  
  tags = merge(local.common_tags, {
    Name = local.cluster_name
    Type = "EKS-Cluster"
  })
}

#==========================================
# OIDC IDENTITY PROVIDER (for IRSA)
# Enables IAM Roles for Service Accounts
#==========================================

data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0
  
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-oidc"
    Type = "OIDC-Provider"
  })
}

#==========================================
# EKS NODE GROUP
# Worker nodes deployed in PRIVATE SUBNETS for security
#==========================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-nodes"
  node_role_arn   = var.node_group_role_arn
  
  # SECURITY: Deploy nodes in PRIVATE subnets only
  subnet_ids = var.private_subnet_ids
  
  # Instance configuration
  instance_types = var.node_group_instance_types
  ami_type       = var.node_group_ami_type
  capacity_type  = var.node_group_capacity_type
  disk_size      = var.node_group_disk_size
  
  # Scaling configuration (max 3 nodes as per requirements)
  scaling_config {
    desired_size = var.node_group_desired_capacity
    max_size     = var.node_group_max_capacity
    min_size     = var.node_group_min_capacity
  }
  
  # Update configuration for rolling updates
  update_config {
    max_unavailable = 1
  }
  
  # Remote access configuration (optional, for debugging)
  # Commented out for security - use SSM instead
  # remote_access {
  #   ec2_ssh_key = var.key_pair_name
  #   source_security_group_ids = [var.bastion_security_group_id]
  # }
  
  # Labels for pod scheduling
  labels = {
    Environment = var.environment
    NodeGroup   = "main"
    Purpose     = "geodish-app"
  }
  
  # Taints for dedicated workloads (if needed)
  # taint {
  #   key    = "dedicated"
  #   value  = "geodish"
  #   effect = "NO_SCHEDULE"
  # }
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-nodes"
    Type = "EKS-Node-Group"
    # Auto-scaling tags
    "k8s.io/cluster-autoscaler/enabled"                = var.enable_cluster_autoscaler
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
  })
  
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  # lifecycle {
  #   ignore_changes = [scaling_config[0].desired_size]
  # }
}

#==========================================
# EKS ADD-ONS
# Essential cluster components
#==========================================

# VPC CNI Add-on (networking) - Fixed: Removed service_account_role_arn
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  # Removed problematic service_account_role_arn line
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-vpc-cni"
  })
  
  depends_on = [aws_eks_node_group.main]
}

# CoreDNS Add-on (DNS resolution)
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-coredns"
  })
  
  depends_on = [aws_eks_node_group.main]
}

# Kube-proxy Add-on (networking proxy)
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-kube-proxy"
  })
  
  depends_on = [aws_eks_node_group.main]
}

# # EBS CSI Driver Add-on (for persistent volumes) - Fixed: Removed service_account_role_arn for now
# resource "aws_eks_addon" "ebs_csi_driver" {
#   count = var.enable_ebs_csi_driver ? 1 : 0
  
#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = "aws-ebs-csi-driver"
#   addon_version               = data.aws_eks_addon_version.ebs_csi.version
#   resolve_conflicts_on_create = "OVERWRITE"
#   # Removed problematic service_account_role_arn line for now
#   # We'll configure IRSA separately after cluster is working
  
#   tags = merge(local.common_tags, {
#     Name = "${local.cluster_name}-ebs-csi-driver"
#   })
  
#   depends_on = [aws_eks_node_group.main]
# }

#==========================================
# DATA SOURCES for Add-on Versions
#==========================================

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

# data "aws_eks_addon_version" "ebs_csi" {
#   addon_name         = "aws-ebs-csi-driver"
#   kubernetes_version = aws_eks_cluster.main.version
#   most_recent        = true
# }

#==========================================
# AWS-AUTH CONFIGMAP
# Manages cluster access permissions
#==========================================

# Note: In production, consider using aws-auth configmap directly
# or using external tools like eksctl for user management

locals {
  aws_auth_configmap = {
    mapRoles = concat([
      {
        rolearn  = var.node_group_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ], var.map_roles)
    
    mapUsers    = var.map_users
    mapAccounts = var.map_accounts
  }
}

#==========================================
# KUBERNETES PROVIDER CONFIGURATION
# For managing Kubernetes resources directly
#==========================================

# Note: This will be used by parent modules to configure kubectl access
# The actual configuration will be done in the environment-specific files

#==========================================
# CLUSTER SECURITY ENHANCEMENTS
#==========================================

# Security Group Rules are handled by the security-groups module
# VPC configuration ensures private subnet deployment
# IRSA enables fine-grained permissions for workloads

#==========================================
# NODE GROUP LAUNCH TEMPLATE (Optional)
# For advanced node configuration
#==========================================

resource "aws_launch_template" "node_group" {
  count = var.node_group_capacity_type == "SPOT" ? 1 : 0
  
  name_prefix   = "${local.cluster_name}-node-"
  description   = "Launch template for EKS node group"
  image_id      = data.aws_ssm_parameter.eks_ami_release_version.value
  instance_type = var.node_group_instance_types[0]
  
  vpc_security_group_ids = var.node_security_group_ids
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    bootstrap_arguments = ""
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.cluster_name}-node"
    })
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Get the latest EKS optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.main.version}/amazon-linux-2/recommended/release_version"
}
