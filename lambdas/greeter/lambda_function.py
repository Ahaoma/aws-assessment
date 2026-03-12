import json
import os
import uuid
from datetime import datetime, timezone

import boto3

region = os.environ.get("EXECUTING_REGION") or os.environ.get("AWS_REGION")

dynamodb = boto3.client("dynamodb", region_name=region)
sns = boto3.client("sns", region_name="us-east-1")  # SNS topic lives in us-east-1


def handler(event, context):
    record_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    # Write record to regional DynamoDB table
    dynamodb.put_item(
        TableName=os.environ["DYNAMODB_TABLE"],
        Item={
            "id":        {"S": record_id},
            "timestamp": {"S": timestamp},
            "region":    {"S": region},
            "path":      {"S": "/greet"},
        },
    )

    # Publish verification payload to Unleash live SNS topic
    payload = {
        "email":  os.environ["CANDIDATE_EMAIL"],
        "source": "Lambda",
        "region": region,
        "repo":   os.environ["CANDIDATE_REPO"],
    }
    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Message=json.dumps(payload),
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message":   "Hello from Unleash live!",
            "region":    region,
            "id":        record_id,
            "timestamp": timestamp,
        }),
    }
