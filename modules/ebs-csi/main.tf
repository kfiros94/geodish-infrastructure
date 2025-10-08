# modules/ebs-csi/main.tf

# EBS CSI Driver Add-on
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
}

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach AWS managed policy for EBS CSI Driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Storage Class for EBS volumes (GP3 - latest generation)
resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Delete"
  allow_volume_expansion = true
  volume_binding_mode   = "WaitForFirstConsumer"
  
  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    encrypted  = "true"
    iops       = "3000"
    throughput = "125"
  }
}

# Additional Storage Class for MongoDB (Retain policy)
resource "kubernetes_storage_class" "ebs_mongodb" {
  metadata {
    name = "ebs-mongodb"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Retain"
  allow_volume_expansion = true
  volume_binding_mode   = "WaitForFirstConsumer"
  
  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    encrypted  = "true"
    iops       = "3000"
    throughput = "125"
  }
}
