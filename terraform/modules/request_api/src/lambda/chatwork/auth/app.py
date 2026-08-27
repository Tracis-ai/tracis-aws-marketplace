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
                "body": "Unsupported or invalid request body",
            }

        # Authorize request
        auth_response = authorize_request(
            headers,
            raw_body,
            json_body,
        )
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


def authorize_request(
    headers: dict,
    body: str,
    json_body: dict,
) -> dict:
    signature = headers.get("x-chatworkwebhooksignature")
    if not signature:
        logger.error("Missing required Chatwork headers")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "body": "No Required Header",
        }

    req_timestamp = json_body.get("webhook_event_time")
    try:
        timestamp = int(req_timestamp)
    except (TypeError, ValueError):
        logger.error("Invalid Chatwork webhook_event_time")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "body": "Invalid request timestamp",
        }

    # Replay attack protection
    now = datetime.datetime.now().timestamp()
    if abs(now - timestamp) > 60 * 5:
        logger.error("Request timestamp is too old")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "body": "Request timestamp is too old",
        }

    secrets = parameters.get_secret(
        CHAT_TOOLS_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    webhook_token = secrets.get("CHATWORK_WEBHOOK_TOKEN")
    if not webhook_token:
        logger.error("CHATWORK_WEBHOOK_TOKEN not found in secrets")
        raise ValueError("CHATWORK_WEBHOOK_TOKEN in secrets is missing or invalid")

    # Signature verification
    # https://developer.chatwork.com/docs/webhook#%E3%83%AA%E3%82%AF%E3%82%A8%E3%82%B9%E3%83%88%E3%81%AE%E7%BD%B2%E5%90%8D%E6%A4%9C%E8%A8%BC
    secret_key = base64.b64decode(webhook_token)
    hmac_message = hmac.new(
        secret_key,
        body.encode("utf-8"),
        hashlib.sha256,
    )
    expected_signature = base64.b64encode(hmac_message.digest()).decode()

    if not hmac.compare_digest(expected_signature, signature):
        logger.error("Chatwork request signature verification failed")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "body": "Failed signature verification",
        }

    logger.info("Chatwork request signature verified successfully")
    return {
        "statusCode": HTTPStatus.OK,
    }
