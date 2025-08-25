#!/bin/bash

# AWS Resource Monitoring Deployment Script
# This script deploys the complete automation solution

set -e

# Configuration
STACK_NAME="aws-resource-monitoring"
EMAIL_ADDRESS=""
REPORT_TIME="10:00"  # UTC time
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}AWS Resource Monitoring Automation Deployment${NC}"
echo "=============================================="

# Check if email is provided
if [ -z "$EMAIL_ADDRESS" ]; then
    echo -e "${RED}Error: Please set EMAIL_ADDRESS in this script${NC}"
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install AWS CLI${NC}"
    exit 1
fi

# Check if AWS Config is enabled
echo -e "${YELLOW}Checking AWS Config status...${NC}"
CONFIG_STATUS=$(aws configservice describe-configuration-recorders --region $REGION --query 'ConfigurationRecorders[0].recordingGroup.allSupported' --output text 2>/dev/null || echo "None")

if [ "$CONFIG_STATUS" != "True" ]; then
    echo -e "${RED}Warning: AWS Config is not enabled or not recording all resources${NC}"
    echo "Please enable AWS Config to track all resource types for complete monitoring"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create Lambda layer with dependencies
echo -e "${YELLOW}Creating Lambda layer with dependencies...${NC}"
mkdir -p layer/python
pip install -r requirements.txt -t layer/python/
cd layer && zip -r ../python-dependencies.zip . && cd ..

# Create temporary S3 bucket for deployment artifacts
TEMP_BUCKET="temp-deployment-$(date +%s)-$(whoami)"
echo -e "${YELLOW}Creating temporary S3 bucket: $TEMP_BUCKET${NC}"
aws s3 mb s3://$TEMP_BUCKET --region $REGION

# Upload layer
echo -e "${YELLOW}Uploading Lambda layer...${NC}"
aws s3 cp python-dependencies.zip s3://$TEMP_BUCKET/layers/python-dependencies.zip

# Update CloudFormation template with actual Lambda code
echo -e "${YELLOW}Preparing Lambda function code...${NC}"
LAMBDA_CODE=$(cat dailyReourceInventory.py | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Create temporary template with embedded code
cp cloudformation-template.yaml temp-template.yaml
sed -i "s|# Placeholder - will be updated with actual code.*|$(cat dailyReourceInventory.py | sed 's/|/\\|/g')|" temp-template.yaml

# Deploy CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file temp-template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EmailAddress=$EMAIL_ADDRESS \
        ReportTime=$REPORT_TIME \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Get stack outputs
echo -e "${YELLOW}Getting stack outputs...${NC}"
LAMBDA_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue' --output text)
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' --output text)

# Update Lambda function code
echo -e "${YELLOW}Updating Lambda function with actual code...${NC}"
zip -j function.zip dailyReourceInventory.py
aws lambda update-function-code \
    --function-name $LAMBDA_ARN \
    --zip-file fileb://function.zip \
    --region $REGION

# Verify SES email address
echo -e "${YELLOW}Verifying SES email address...${NC}"
aws ses verify-email-identity --email-address $EMAIL_ADDRESS --region $REGION

# Test the function
echo -e "${YELLOW}Testing Lambda function...${NC}"
aws lambda invoke \
    --function-name $LAMBDA_ARN \
    --payload '{}' \
    --region $REGION \
    response.json

# Clean up temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf layer python-dependencies.zip function.zip temp-template.yaml response.json
aws s3 rm s3://$TEMP_BUCKET/layers/python-dependencies.zip
aws s3 rb s3://$TEMP_BUCKET

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Configuration Summary:"
echo "- Stack Name: $STACK_NAME"
echo "- Email Address: $EMAIL_ADDRESS"
echo "- Report Time: $REPORT_TIME UTC (daily)"
echo "- S3 Bucket: $BUCKET_NAME"
echo "- Lambda Function: $LAMBDA_ARN"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "1. Check your email for SES verification"
echo "2. Reports will be generated daily at $REPORT_TIME UTC"
echo "3. Excel reports are stored in S3 bucket: $BUCKET_NAME"
echo "4. AWS Config must be enabled for complete resource tracking"
echo "5. CloudTrail should be enabled for user attribution"
echo ""
echo -e "${GREEN}Setup complete! You'll receive your first report tomorrow.${NC}"