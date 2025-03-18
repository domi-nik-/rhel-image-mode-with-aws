#!/bin/bash

set -e  # Abort script on error


ROLE_NAME="vmimport"
POLICY_NAME="vmimport-s3-policy"
REGISTRY_URL="quay.io/dbittl"
IMAGE="rhel-nginx-aws:latest"


export BUCKET_NAME=$(aws s3api create-bucket \
    --bucket rhel-nginx-aws-bucket$(uuidgen | tr -d - | tr '[:upper:]' '[:lower:]' ) \
    --region eu-central-1 \
    --create-bucket-configuration LocationConstraint=eu-central-1 \
    --output json | jq -r '.Location' | sed -E 's|http://(.*)\.s3.amazonaws.com/|\1|')

    
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

# Attach Policy to Role
aws iam put-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME --policy-document file://role-policy.json

# Cleanup temporary files
rm trust-policy.json role-policy.json

echo "Role '$ROLE_NAME', Bucket $BUCKET_NAME and policy '$POLICY_NAME' created."

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