import base64
import datetime
import hashlib
import hmac
import json
import logging
import os
from http import HTTPStatus
from urllib.parse import parse_qs

import boto3
from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")

NO_RETRY_HEADER = {"x-slack-no-retry": "1"}
SLACK_SECRET_ARN = os.environ.get("SLACK_SECRET_ARN")
ENQUEUE_FUNCTION_NAME = os.environ.get("ENQUEUE_FUNCTION_NAME")

if not SLACK_SECRET_ARN:
    logger.error("SLACK_SECRET_ARN is not set")
    raise ValueError("SLACK_SECRET_ARN is not set")

if not ENQUEUE_FUNCTION_NAME:
    logger.error("ENQUEUE_FUNCTION_NAME is not set")
    raise ValueError("ENQUEUE_FUNCTION_NAME is not set")


def lambda_handler(event, context):
    try:
        headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}

        body = event.get("body", "")
        if event.get("isBase64Encoded", False):
            body = base64.b64decode(body).decode("utf-8")

        json_body = normalize_body(headers, body)

        # URL検証チャレンジ対応
        if "challenge" in json_body:
            logger.info("Responding to Slack URL verification challenge")
            res_body = {"challenge": json_body["challenge"]}
            return {
                "statusCode": HTTPStatus.OK,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps(res_body),
            }

        # リクエスト認証
        auth_response = authorize_request(headers, body)
        if auth_response["statusCode"] != HTTPStatus.OK:
            return auth_response

        # 認証成功時は enqueue Lambda を非同期呼び出ししてレスポンス返却
        lambda_client.invoke(
            FunctionName=ENQUEUE_FUNCTION_NAME,
            InvocationType="Event",
            Payload=body.encode("utf-8"),
        )
        logger.info("Successfully invoked enqueue function")

        return {
            "statusCode": HTTPStatus.OK,
        }

    except Exception as e:
        logger.exception(f"Error handling request: {e}")
        return {
            "statusCode": HTTPStatus.INTERNAL_SERVER_ERROR,
            "headers": NO_RETRY_HEADER,
            "body": "An error occurred while processing authentication.",
        }


def authorize_request(headers, body):
    # signing_secret取得
    secrets = parameters.get_secret(
        SLACK_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    signing_secret = secrets.get("SIGNING_SECRET")
    if not signing_secret:
        logger.error("SIGNING_SECRET not found in secrets")
        raise ValueError("SIGNING_SECRET in secrets is missing or invalid")

    # ヘッダーから署名検証に必要な情報を取得
    signature = headers.get("x-slack-signature")
    timestamp = headers.get("x-slack-request-timestamp")
    if not (timestamp) or not (signature):
        logger.error("Missing required Slack headers")
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "headers": NO_RETRY_HEADER,
            "body": "No Requred Header",
        }

    # リプレイ攻撃対策:
    # タイムスタンプが現在時刻より5分以上前の場合は拒否
    now = datetime.datetime.now().timestamp()
    if abs(now - int(timestamp)) > 60 * 5:
        logger.error("Request timestamp is too old")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "headers": NO_RETRY_HEADER,
            "body": "Request timestamp is too old",
        }

    # 署名検証:
    # https://docs.slack.dev/authentication/verifying-requests-from-slack/#validating-a-request
    # Create the basestring as described by Slack
    sig_basestring = f"v0:{timestamp}:{body}"

    # Create HMAC SHA256 hash using the signing secret
    hmac_message = hmac.new(
        bytes(signing_secret, "UTF-8"),
        bytes(sig_basestring, "UTF-8"),
        hashlib.sha256,
    )
    expected_signature = f"v0={hmac_message.hexdigest()}"

    # Compare the expected signature with the one from the header
    if not hmac.compare_digest(expected_signature, signature):
        logger.error("Slack request signature verification failed")
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "headers": NO_RETRY_HEADER,
            "body": "Failed signature verification",
        }

    # 検証成功
    logger.info("Slack request signature verified successfully")
    return {
        "statusCode": HTTPStatus.OK,
    }


def normalize_body(headers: dict, body: str) -> dict:
    if not body:
        return {}

    content_type = headers.get("content-type", "")

    # application/x-www-form-urlencoded（Slack slash command）
    if content_type.startswith("application/x-www-form-urlencoded"):
        parsed_body = parse_qs(body)
        flat_body = {
            k: v[0] if isinstance(v, list) and v else v for k, v in parsed_body.items()
        }
        return {"event": flat_body}

    # application/json (Slack Events API)
    if content_type.startswith("application/json"):
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return {}

    return {}
