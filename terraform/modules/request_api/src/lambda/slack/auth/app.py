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
                "headers": NO_RETRY_HEADER,
                "body": "Unsupported or invalid request body",
            }

        # Authorize request
        auth_response = authorize_request(headers, raw_body)
        if auth_response["statusCode"] != HTTPStatus.OK:
            return auth_response

        if json_body.get("type") == "url_verification":
            challenge = json_body.get("challenge")
            if not isinstance(challenge, str) or not challenge:
                return bad_request()
            return {
                "statusCode": HTTPStatus.OK,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"challenge": challenge}),
            }

        request_type = json_body.get("type")
        if not isinstance(request_type, str) or not request_type:
            return bad_request()
        if request_type != "event_callback":
            logger.info("Ignoring unsupported request type")
            return {"statusCode": HTTPStatus.OK}

        slack_event = json_body.get("event")
        if not isinstance(slack_event, dict):
            return bad_request()
        event_type = slack_event.get("type")
        if not isinstance(event_type, str) or not event_type:
            return bad_request()
        if event_type != "app_mention":
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
        "headers": NO_RETRY_HEADER,
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
    if payload.get("type") != "event_callback":
        return False
    if not all(
        isinstance(payload.get(key), str) and payload[key]
        for key in ("team_id", "event_id")
    ):
        return False

    event = payload.get("event")
    if not isinstance(event, dict) or event.get("type") != "app_mention":
        return False
    if not all(
        isinstance(event.get(key), str) and event[key] for key in ("channel", "ts")
    ):
        return False

    return isinstance(event.get("text"), str) and (
        "thread_ts" not in event or isinstance(event["thread_ts"], str)
    )


def authorize_request(headers, body):
    signature = headers.get("x-slack-signature")
    req_timestamp = headers.get("x-slack-request-timestamp")
    if not req_timestamp or not signature:
        logger.error("Missing required Slack headers")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "headers": NO_RETRY_HEADER,
            "body": "No Required Header",
        }

    if not signature.isascii() or not req_timestamp.isascii():
        return bad_request()

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
    if not now - 60 * 5 <= timestamp <= now + 60 * 5:
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
