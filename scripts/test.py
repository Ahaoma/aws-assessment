#!/usr/bin/env python3
"""
Unleash live – AWS Assessment End-to-End Test Script

Steps performed:
  1. Authenticate with Cognito (us-east-1) and retrieve a JWT
  2. Concurrently call GET /greet in both regions with the JWT
  3. Concurrently call POST /dispatch in both regions to trigger ECS tasks
  4. Assert that each response's region matches the expected region and print latency

Usage:
    pip install boto3 requests

    python scripts/test.py \
        --user-pool-id  us-east-1_XXXXXXXXX \
        --client-id     XXXXXXXXXXXXXXXXXXXXXXXXXX \
        --username      your@email.com \
        --password      'YourPassword1!' \
        --api-us        https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com \
        --api-eu        https://xxxxxxxxxx.execute-api.eu-west-1.amazonaws.com
"""

import argparse
import concurrent.futures
import json
import sys
import time

import boto3
import requests


def parse_args():
    parser = argparse.ArgumentParser(description="Unleash live end-to-end test")
    parser.add_argument("--user-pool-id", required=True)
    parser.add_argument("--client-id",    required=True)
    parser.add_argument("--username",     required=True)
    parser.add_argument("--password",     required=True)
    parser.add_argument("--api-us",       required=True, help="API Gateway base URL – us-east-1")
    parser.add_argument("--api-eu",       required=True, help="API Gateway base URL – eu-west-1")
    return parser.parse_args()


# Step 1: Authenticate with Cognito ######################################

def get_jwt(user_pool_id: str, client_id: str, username: str, password: str) -> str:
    print("Step 1: Authenticating with Cognito (us-east-1)...")
    client = boto3.client("cognito-idp", region_name="us-east-1")

    response = client.initiate_auth(
        AuthFlow="USER_PASSWORD_AUTH",
        ClientId=client_id,
        AuthParameters={
            "USERNAME": username,
            "PASSWORD": password,
        },
    )
    token = response["AuthenticationResult"]["IdToken"]
    print("  JWT retrieved successfully.\n")
    return token


# Helper: call one endpoint and measure latency ###########################################

def call_endpoint(method: str, url: str, headers: dict) -> dict:
    start = time.time()
    response = requests.request(method, url, headers=headers)
    latency_ms = round((time.time() - start) * 1000, 2)

    try:
        body = response.json()
    except Exception:
        body = {}

    return {
        "url":        url,
        "status":     response.status_code,
        "body":       body,
        "latency_ms": latency_ms,
    }


# Print result and return whether the region assertion passed ################################

def print_result(label: str, expected_region: str, result: dict) -> bool:
    actual   = result["body"].get("region", "N/A")
    passed   = actual == expected_region

    print(f"  [{label}]")
    print(f"    Status   : {result['status']}")
    print(f"    Latency  : {result['latency_ms']} ms")
    print(f"    Region   : {actual}")
    print(f"    Assert   : {'PASS' if passed else 'FAIL'} "
          f"(expected '{expected_region}', got '{actual}')")
    print(f"    Response : {json.dumps(result['body'], indent=2)}\n")
    return passed


def main():
    args = parse_args()

    # Step 1 – Get JWT
    jwt = get_jwt(args.user_pool_id, args.client_id, args.username, args.password)
    headers = {"Authorization": jwt, "Content-Type": "application/json"}

    all_passed = True

    # Step 2 – Concurrently call /greet in both regions
    print("Step 2: Concurrently calling GET /greet in both regions...")
    with concurrent.futures.ThreadPoolExecutor() as pool:
        f_us = pool.submit(call_endpoint, "GET", f"{args.api_us}/greet", headers)
        f_eu = pool.submit(call_endpoint, "GET", f"{args.api_eu}/greet", headers)
        greet_us = f_us.result()
        greet_eu = f_eu.result()

    print()
    all_passed &= print_result("us-east-1 /greet", "us-east-1", greet_us)
    all_passed &= print_result("eu-west-1 /greet", "eu-west-1", greet_eu)
    delta = abs(greet_us["latency_ms"] - greet_eu["latency_ms"])
    print(f"  Geographic latency delta: {delta} ms "
          f"(us-east-1: {greet_us['latency_ms']} ms, eu-west-1: {greet_eu['latency_ms']} ms)\n")

    # Step 3 – Concurrently call /dispatch in both regions
    print("Step 3: Concurrently calling POST /dispatch in both regions...")
    with concurrent.futures.ThreadPoolExecutor() as pool:
        f_us = pool.submit(call_endpoint, "POST", f"{args.api_us}/dispatch", headers)
        f_eu = pool.submit(call_endpoint, "POST", f"{args.api_eu}/dispatch", headers)
        dispatch_us = f_us.result()
        dispatch_eu = f_eu.result()

    print()
    all_passed &= print_result("us-east-1 /dispatch", "us-east-1", dispatch_us)
    all_passed &= print_result("eu-west-1 /dispatch", "eu-west-1", dispatch_eu)

    # Step 4 – Summary
    print("=" * 55)
    if all_passed:
        print("ALL ASSERTIONS PASSED")
    else:
        print("ONE OR MORE ASSERTIONS FAILED")
        sys.exit(1)
    print("=" * 55)


if __name__ == "__main__":
    main()
