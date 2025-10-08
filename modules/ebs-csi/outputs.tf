# modules/ebs-csi/outputs.tf

#==========================================
# EBS CSI Driver Outputs
#==========================================

output "storage_class_name" {
  description = "Name of the default EBS storage class"
  value       = kubernetes_storage_class.ebs_gp3.metadata[0].name
}

output "mongodb_storage_class_name" {
  description = "Name of the MongoDB-specific storage class"
  value       = kubernetes_storage_class.ebs_mongodb.metadata[0].name
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.name
}

output "addon_version" {
  description = "Version of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi.addon_version
}

output "addon_status" {
  description = "Status of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi.status
}

#==========================================
# Storage Configuration for Applications
#==========================================

output "storage_classes" {
  description = "Available storage classes for applications"
  value = {
    default = {
      name         = kubernetes_storage_class.ebs_gp3.metadata[0].name
      type         = "gp3"
      reclaim      = "Delete"
      provisioner  = "ebs.csi.aws.com"
      encrypted    = true
    }
    mongodb = {
      name         = kubernetes_storage_class.ebs_mongodb.metadata[0].name
      type         = "gp3"
      reclaim      = "Retain"
      provisioner  = "ebs.csi.aws.com"
      encrypted    = true
    }
  }
}

#==========================================
# Helm Values for MongoDB
#==========================================

output "mongodb_helm_values" {
  description = "Storage configuration for MongoDB Helm chart"
  value = {
    persistence = {
      enabled      = true
      storageClass = kubernetes_storage_class.ebs_mongodb.metadata[0].name
      size         = "20Gi"
    }
  }
}
