# modules/ebs-csi/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# Attach AWS managed policy for EBS CSI Driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Install EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

# ⭐ ADD THIS: Wait for EBS CSI driver to be fully ready
resource "time_sleep" "wait_for_ebs_csi" {
  create_duration = "60s"
  
  depends_on = [aws_eks_addon.ebs_csi]
}

# Storage Class for general purpose (gp3)
resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  # ⭐ UPDATE THIS: Wait for EBS CSI to be ready
  depends_on = [time_sleep.wait_for_ebs_csi]
}

# Storage Class optimized for MongoDB
resource "kubernetes_storage_class" "ebs_mongodb" {
  metadata {
    name = "ebs-mongodb"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy        = "Retain"
  volume_binding_mode   = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
    iops      = "3000"
    throughput = "125"
  }

  # ⭐ UPDATE THIS: Wait for EBS CSI to be ready
  depends_on = [time_sleep.wait_for_ebs_csi]
}