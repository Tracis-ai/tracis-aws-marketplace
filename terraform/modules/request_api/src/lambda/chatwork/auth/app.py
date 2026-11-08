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
        try:
            headers, raw_body = parse_request(event)
        except (ValueError, TypeError, UnicodeError):
            logger.warning("Invalid request envelope")
            return bad_request()

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

        event_type = json_body.get("webhook_event_type")
        if not isinstance(event_type, str) or not event_type:
            return bad_request()
        if event_type != "mention_to_me":
            logger.info("Ignoring unsupported event type")
            return {"statusCode": HTTPStatus.OK}

        if not valid_event(json_body):
            logger.warning("Invalid event")
            return bad_request()

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
        logger.error(
            "Authentication processing failed", extra={"error_type": type(e).__name__}
        )
        return {
            "statusCode": HTTPStatus.INTERNAL_SERVER_ERROR,
            "body": "An error occurred while processing authentication.",
        }


def bad_request():
    return {
        "statusCode": HTTPStatus.BAD_REQUEST,
        "body": "Invalid or unsupported request",
    }


def parse_request(event):
    if not isinstance(event, dict):
        raise ValueError("Invalid request envelope")

    headers = event.get("headers")
    if not isinstance(headers, dict) or any(
        not isinstance(key, str) or not isinstance(value, str)
        for key, value in headers.items()
    ):
        raise ValueError("Invalid request headers")

    raw_body = event.get("body")
    encoded = event.get("isBase64Encoded", False)
    if not isinstance(raw_body, str) or not isinstance(encoded, bool):
        raise ValueError("Invalid request body")
    if encoded:
        raw_body = base64.b64decode(raw_body, validate=True).decode("utf-8")
    raw_body.encode("utf-8")

    return {key.lower(): value for key, value in headers.items()}, raw_body


def parse_json_body(headers: dict, body: str) -> dict:
    content_type = headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if not body or content_type != "application/json":
        return {}

    try:
        parsed = json.loads(body)
    except (ValueError, RecursionError):
        return {}

    return parsed if isinstance(parsed, dict) else {}


def valid_event(payload):
    if payload.get("webhook_event_type") != "mention_to_me":
        return False
    if (
        not isinstance(payload.get("webhook_setting_id"), str)
        or not payload["webhook_setting_id"]
    ):
        return False

    event = payload.get("webhook_event")
    if not isinstance(event, dict):
        return False
    if not all(
        type(event.get(key)) is int and event[key] > 0
        for key in ("room_id", "from_account_id", "to_account_id", "send_time")
    ):
        return False
    if (
        not isinstance(event.get("message_id"), str)
        or not event["message_id"].isascii()
        or not event["message_id"].isdigit()
    ):
        return False

    return isinstance(event.get("body"), str) and (
        type(event.get("update_time")) is int and event["update_time"] >= 0
    )


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

    if not signature.isascii():
        return bad_request()

    req_timestamp = json_body.get("webhook_event_time")
    if type(req_timestamp) is not int:
        return bad_request()
    timestamp = req_timestamp

    # Replay attack protection
    now = datetime.datetime.now().timestamp()
    if not now - 60 * 5 <= timestamp <= now + 60 * 5:
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
