import base64
import datetime
import hashlib
import hmac
import json
import logging
import os
from http import HTTPStatus

import boto3
from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")

NO_RETRY_HEADER = {"x-slack-no-retry": "1"}
CHAT_TOOLS_SECRET_ARN = os.environ.get("CHAT_TOOLS_SECRET_ARN")
ENQUEUE_FUNCTION_NAME = os.environ.get("ENQUEUE_FUNCTION_NAME")

if not CHAT_TOOLS_SECRET_ARN:
    logger.error("CHAT_TOOLS_SECRET_ARN is not set")
    raise ValueError("CHAT_TOOLS_SECRET_ARN is not set")

if not ENQUEUE_FUNCTION_NAME:
    logger.error("ENQUEUE_FUNCTION_NAME is not set")
    raise ValueError("ENQUEUE_FUNCTION_NAME is not set")


def lambda_handler(event, context):
    try:
        headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}

        raw_body = event.get("body", "")
        if event.get("isBase64Encoded", False):
            raw_body = base64.b64decode(raw_body).decode("utf-8")

        json_body = parse_json_body(headers, raw_body)
        if not json_body:
            logger.error("Unsupported or invalid request body")
            return {
                "statusCode": HTTPStatus.BAD_REQUEST,
                "headers": NO_RETRY_HEADER,
                "body": "Unsupported or invalid request body",
            }

        # Handle Slack URL verification challenge
        if "challenge" in json_body:
            logger.info("Responding to Slack URL verification challenge")
            res_body = {"challenge": json_body["challenge"]}
            return {
                "statusCode": HTTPStatus.OK,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(res_body),
            }

        # Authorize request
        auth_response = authorize_request(headers, raw_body)
        if auth_response["statusCode"] != HTTPStatus.OK:
            return auth_response

        lambda_client.invoke(
            FunctionName=ENQUEUE_FUNCTION_NAME,
            InvocationType="Event",
            Payload=json.dumps(json_body).encode("utf-8"),
        )
        logger.info("Successfully invoked enqueue function")

        return {
            "statusCode": HTTPStatus.OK,
        }

    except Exception as e:
        logger.exception(f"Error handling request: {e}")
        return {
            "statusCode": HTTPStatus.INTERNAL_SERVER_ERROR,
            "body": "An error occurred while processing authentication.",
        }


def parse_json_body(headers: dict, body: str) -> dict:
    if not body:
        return {}

    content_type = headers.get("content-type", "")
    if content_type.startswith("application/json"):
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return {}

    return {}


def authorize_request(headers, body):
    signature = headers.get("x-slack-signature")
    req_timestamp = headers.get("x-slack-request-timestamp")
    if not (req_timestamp) or not (signature):
        logger.error("Missing required Slack headers")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "headers": NO_RETRY_HEADER,
            "body": "No Required Header",
        }

    try:
        timestamp = int(req_timestamp)
    except ValueError:
        logger.error("Invalid Slack request timestamp")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "headers": NO_RETRY_HEADER,
            "body": "Invalid request timestamp",
        }

    # Replay attack protection
    now = datetime.datetime.now().timestamp()
    if abs(now - timestamp) > 60 * 5:
        logger.error("Request timestamp is too old")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "headers": NO_RETRY_HEADER,
            "body": "Request timestamp is too old",
        }

    secrets = parameters.get_secret(
        CHAT_TOOLS_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    signing_secret = secrets.get("SLACK_SIGNING_SECRET")
    if not signing_secret:
        logger.error("SLACK_SIGNING_SECRET not found in secrets")
        raise ValueError("SLACK_SIGNING_SECRET in secrets is missing or invalid")

    # Signature verification
    # https://docs.slack.dev/authentication/verifying-requests-from-slack/#validating-a-request
    sig_basestring = f"v0:{req_timestamp}:{body}"
    hmac_message = hmac.new(
        signing_secret.encode("utf-8"),
        sig_basestring.encode("utf-8"),
        hashlib.sha256,
    )
    expected_signature = f"v0={hmac_message.hexdigest()}"

    if not hmac.compare_digest(expected_signature, signature):
        logger.error("Slack request signature verification failed")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "headers": NO_RETRY_HEADER,
            "body": "Failed signature verification",
        }

    logger.info("Slack request signature verified successfully")
    return {
        "statusCode": HTTPStatus.OK,
    }
