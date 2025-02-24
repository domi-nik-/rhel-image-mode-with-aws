#!/bin/bash

set -e  # Abort script on error

ROLE_NAME="vmimport"
POLICY_NAME="vmimport-s3-policy"
REGISTRY_URL="quay.io/dbittl"
IMAGE="rhel-nginx-aws:latest"
AWS_REGION="eu-central-1"

# Check if the role already exists
if aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    echo "Role '$ROLE_NAME' already exists. Skipping creation."
else
    echo "Creating IAM role '$ROLE_NAME'..."

    # Create Trust Policy for VM Import
    cat > trust-policy.json <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF

    # Create Role
    aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json
    rm trust-policy.json
    echo "IAM Role '$ROLE_NAME' created successfully!"
fi

# Check if the policy is already attached
if aws iam get-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME >/dev/null 2>&1; then
    echo "Policy '$POLICY_NAME' is already attached to the role '$ROLE_NAME'. Skipping policy creation."
else
    echo "Creating and attaching policy '$POLICY_NAME' to role '$ROLE_NAME'..."

    # Create Role-Policy for S3 Access
    cat > role-policy.json <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket" 
         ],
         "Resource": [
            "arn:aws:s3:::$BUCKET_NAME",
            "arn:aws:s3:::$BUCKET_NAME/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::$BUCKET_NAME",
            "arn:aws:s3:::$BUCKET_NAME/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF

    # Attach the policy to the role
    aws iam put-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME --policy-document file://role-policy.json
    rm role-policy.json
    echo "Policy '$POLICY_NAME' attached successfully!"
fi

# Check if a bucket with the same prefix already exists
EXISTING_BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'rhel-nginx-aws-bucket')].Name" --output text)

if [ -n "$EXISTING_BUCKET" ]; then
    echo "Found existing bucket: $EXISTING_BUCKET"
    export BUCKET_NAME="$EXISTING_BUCKET"
else
    echo "Creating a new S3 bucket..."
    export BUCKET_NAME=$(aws s3api create-bucket \
        --bucket rhel-nginx-aws-bucket$(uuidgen | tr -d - | tr '[:upper:]' '[:lower:]' ) \
        --region $AWS_REGION \
        --create-bucket-configuration LocationConstraint=$AWS_REGION \
        --output json | jq -r '.Location' | sed -E 's|http://(.*)\.s3.amazonaws.com/|\1|')
    echo "S3 bucket '$BUCKET_NAME' created successfully!"
fi

echo "Start Podman-Container..."
sudo podman run --rm -it --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v $HOME/.aws:/root/.aws:ro \
    --env AWS_PROFILE=default \
    registry.redhat.io/rhel9/bootc-image-builder:latest \
    --type ami \
    --aws-ami-name rhel-nginx-aws \
    --aws-bucket $BUCKET_NAME \
    --aws-region $AWS_REGION \
    $REGISTRY_URL/$IMAGE
