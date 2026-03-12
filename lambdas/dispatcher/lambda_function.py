import json
import os

import boto3

region = os.environ.get("EXECUTING_REGION") or os.environ.get("AWS_REGION")

ecs = boto3.client("ecs", region_name=region)


def handler(event, context):
    try:
        response = ecs.run_task(
            cluster=os.environ["ECS_CLUSTER_ARN"],
            taskDefinition=os.environ["ECS_TASK_DEFINITION_ARN"],
            launchType="FARGATE",
            count=1,
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets":        [os.environ["ECS_SUBNET_ID"]],
                    "securityGroups": [os.environ["ECS_SECURITY_GROUP_ID"]],
                    "assignPublicIp": "ENABLED",  # No NAT Gateway needed
                }
            },
        )

        failures = response.get("failures", [])
        if failures:
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "error":    "ECS task failed to launch",
                    "failures": failures,
                    "region":   region,
                }),
            }

        task_arn = response["tasks"][0]["taskArn"]
        print(f"ECS task launched: {task_arn} in {region}")

    except Exception as exc:
        print(f"RunTask error: {exc}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(exc), "region": region}),
        }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "ECS Fargate task dispatched",
            "taskArn": task_arn,
            "region":  region,
        }),
    }
