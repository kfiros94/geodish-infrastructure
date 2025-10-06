#!/bin/bash
# modules/eks/user_data.sh

# EKS Node Bootstrap Script
# This script is used when deploying nodes with custom launch templates

set -o xtrace

# Variables passed from Terraform (use exact variable names from templatefile)
CLUSTER_NAME="${cluster_name}"
CLUSTER_ENDPOINT="${cluster_endpoint}"
CLUSTER_CA="${cluster_ca}"
BOOTSTRAP_ARGS="${bootstrap_arguments}"

# Update the system
/usr/bin/yum update -y

# Install additional packages if needed
/usr/bin/yum install -y amazon-ssm-agent
/usr/bin/systemctl enable amazon-ssm-agent
/usr/bin/systemctl start amazon-ssm-agent

# Configure CloudWatch agent (optional)
/usr/bin/yum install -y amazon-cloudwatch-agent

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh "$CLUSTER_NAME" "$BOOTSTRAP_ARGS"

# Additional custom configurations can be added here
# For example: Docker daemon configuration, custom networking, etc.

# Set up log forwarding to CloudWatch (optional)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/eks/${cluster_name}/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "EKS Node bootstrap completed successfully"
