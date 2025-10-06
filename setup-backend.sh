#!/bin/bash
# setup-backend.sh
# Create S3 bucket and DynamoDB table for Terraform state management

set -e

# Configuration
AWS_REGION="ap-south-1"
BUCKET_NAME="geodish-terraform-state-dev"
DYNAMODB_TABLE="geodish-terraform-locks"
PROJECT_TAG="geodish"

echo "🚀 Setting up Terraform backend infrastructure..."
echo "📍 Region: $AWS_REGION"
echo "🪣 S3 Bucket: $BUCKET_NAME"
echo "🗂️ DynamoDB Table: $DYNAMODB_TABLE"

# Check AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

echo ""
echo "👤 AWS Account: $(aws sts get-caller-identity --query Account --output text)"

# Create S3 bucket for Terraform state
echo ""
echo "🪣 Creating S3 bucket for Terraform state..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 bucket $BUCKET_NAME already exists"
else
    # Create bucket in ap-south-1 (requires specific location constraint)
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    
    echo "✅ Created S3 bucket: $BUCKET_NAME"
fi

# Enable versioning on the bucket
echo "🔄 Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "🔐 Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
echo "🚫 Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Add tags to bucket
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging 'TagSet=[
        {Key=Project,Value='"$PROJECT_TAG"'},
        {Key=Purpose,Value=TerraformState},
        {Key=Environment,Value=dev},
        {Key=ManagedBy,Value=Script}
    ]'

# Create DynamoDB table for state locking
echo ""
echo "🗂️ Creating DynamoDB table for state locking..."

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ DynamoDB table $DYNAMODB_TABLE already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
        --region "$AWS_REGION" \
        --tags Key=Project,Value="$PROJECT_TAG" Key=Purpose,Value=TerraformLocking Key=Environment,Value=dev Key=ManagedBy,Value=Script
    
    echo "✅ Created DynamoDB table: $DYNAMODB_TABLE"
    echo "⏳ Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
fi

echo ""
echo "🎉 Terraform backend setup complete!"
echo ""
echo "Backend configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $AWS_REGION"
echo ""
echo "Next steps:"
echo "  1. cd environments/dev/"
echo "  2. terraform init"
echo "  3. terraform plan"
echo ""
