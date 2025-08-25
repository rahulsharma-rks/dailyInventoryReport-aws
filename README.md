# AWS Resource Monitoring Automation

This solution provides automated daily email reports of all AWS resources in your account, including creation, modification, and deletion tracking with color-coded Excel reports.

## Features

- **Comprehensive Resource Tracking**: Monitors all AWS services (EC2, S3, Lambda, RDS, IAM, etc.)
- **Daily Email Reports**: Automated Excel reports sent at 10:00 AM UTC daily
- **Color-Coded Excel**: 
  - 🟢 Green: Newly created resources
  - 🟡 Yellow: Modified resources
  - 🔴 Red: Deleted resources
  - 🔵 Blue: Existing resources (no changes)
- **User Attribution**: Tracks which IAM user performed each action
- **Detailed Information**: Resource type, state, region, creation/modification dates, tags
- **Automated Cleanup**: Reports stored for 90 days in S3

## Prerequisites

1. **AWS CLI** installed and configured
2. **AWS Config** enabled in your account (required for resource tracking)
3. **CloudTrail** enabled (recommended for user attribution)
4. **SES** access in your region (for email sending)
5. **Python 3.9+** (for local development)

## Quick Setup

### Option 1: Automated Deployment (Recommended)

1. **Edit the deployment script**:
   ```bash
   # For Linux/Mac users
   nano deploy.sh
   
   ```

2. **Set your email address**:
   ```bash
   EMAIL_ADDRESS="your-email@example.com"
   ```

3. **Run the deployment**:
   ```bash
   # Linux/Mac
   chmod +x deploy.sh
   ./deploy.sh
   
   ```

### Option 2: Manual Deployment

1. **Create Lambda Layer**:
   ```bash
   mkdir layer/python
   pip install -r requirements.txt -t layer/python/
   cd layer && zip -r ../python-dependencies.zip . && cd ..
   ```

2. **Deploy CloudFormation Stack**:
   ```bash
   aws cloudformation deploy \
     --template-file cloudformation-template.yaml \
     --stack-name aws-resource-monitoring \
     --parameter-overrides EmailAddress=your-email@example.com \
     --capabilities CAPABILITY_IAM
   ```

3. **Update Lambda Function**:
   ```bash
   zip function.zip dailyReourceInventory.py
   aws lambda update-function-code \
     --function-name aws-resource-monitoring-resource-monitor \
     --zip-file fileb://function.zip
   ```

## Configuration

### Environment Variables (Set automatically by CloudFormation)
- `REPORT_S3_BUCKET`: S3 bucket for storing reports
- `EMAIL_FROM`: Sender email address
- `EMAIL_TO`: Recipient email address

### Customization Options

1. **Change Report Time**: Modify `ReportTime` parameter in CloudFormation
2. **Add More Recipients**: Update the Lambda function's email list
3. **Customize Report Format**: Modify the Excel generation code
4. **Filter Resources**: Add resource type filters in the Lambda function

## Report Structure

The Excel report includes the following columns:

| Column | Description |
|--------|-------------|
| IAM User | User who created/modified the resource |
| Resource ID | Unique identifier of the resource |
| Resource Type | AWS service type (e.g., AWS::EC2::Instance) |
| Current State | Current status of the resource |
| Region | AWS region where resource exists |
| Creation Date | When the resource was created |
| Last Modified | When the resource was last changed |
| Change Type | Created/Modified/Deleted/Existing |
| Tags | Resource tags (key:value pairs) |
| Additional Info | Service-specific details |

## Troubleshooting

### Common Issues

1. **No emails received**:
   - Check SES email verification status
   - Verify Lambda function logs in CloudWatch
   - Ensure SES is available in your region

2. **Empty reports**:
   - Verify AWS Config is enabled and recording
   - Check if resources exist in the account
   - Review Lambda function permissions

3. **Missing user information**:
   - Enable CloudTrail for user attribution
   - Ensure CloudTrail logs are accessible

4. **Lambda timeout**:
   - Increase Lambda timeout (current: 15 minutes)
   - Consider filtering resources for large accounts

### Monitoring

- **CloudWatch Logs**: `/aws/lambda/aws-resource-monitoring-resource-monitor`
- **S3 Reports**: Check the S3 bucket for generated reports
- **Lambda Metrics**: Monitor execution duration and errors

## Cost Considerations

- **AWS Config**: ~$2/month for configuration items
- **Lambda**: Minimal cost for daily execution
- **S3**: Storage costs for reports (auto-deleted after 90 days)
- **SES**: $0.10 per 1,000 emails
- **CloudTrail**: If not already enabled, ~$2/month

## Security

- Lambda function uses least-privilege IAM permissions
- S3 bucket blocks public access
- Reports contain pre-signed URLs with 24-hour expiration
- All data encrypted in transit and at rest

## Customization Examples

### Add Slack Notifications
```python
import requests

def send_slack_notification(webhook_url, message):
    requests.post(webhook_url, json={'text': message})
```

### Filter Specific Resource Types
```python
# In the Lambda function, add filtering
if data.get('resourceType') not in ['AWS::EC2::Instance', 'AWS::S3::Bucket']:
    continue
```

### Custom Email Template
```python
# Modify the email_body variable for HTML formatting
email_body_html = f"""
<html>
<body>
<h2>AWS Resource Report - {yesterday}</h2>
<p>Summary: {summary_text}</p>
</body>
</html>
"""
```

## Support

For issues or questions:
1. Check CloudWatch logs for Lambda execution details
2. Verify AWS Config and CloudTrail are properly configured
3. Ensure all IAM permissions are correctly set
4. Review the CloudFormation stack events for deployment issues
