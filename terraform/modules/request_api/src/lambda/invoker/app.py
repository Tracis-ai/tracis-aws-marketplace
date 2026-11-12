import hashlib
import json
import logging
import os
import urllib.error
import urllib.request
from http import HTTPStatus

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")

AGENT_INVOCATION_URL = os.environ.get("AGENT_INVOCATION_URL")
SETUP_LINKS_INVOCATION_URL = os.environ.get("SETUP_LINKS_INVOCATION_URL")
INVOCATION_TIMEOUT_SECONDS = int(os.environ.get("INVOCATION_TIMEOUT_SECONDS", "295"))
RESPONSE_QUEUE_URL = os.environ.get("RESPONSE_QUEUE_URL")

if not AGENT_INVOCATION_URL:
    logger.error("AGENT_INVOCATION_URL is not set")
    raise ValueError("AGENT_INVOCATION_URL is not set")

if not RESPONSE_QUEUE_URL:
    logger.error("RESPONSE_QUEUE_URL is not set")
    raise ValueError("RESPONSE_QUEUE_URL is not set")


def lambda_handler(event, _):
    batch_item_failures = []

    for record in event.get("Records", []):
        message_attributes = record.get("attributes", {})
        message_group_id = message_attributes.get("MessageGroupId", "default")

        request_message_id = record.get("messageId")
        request_body = record.get("body")
        if not request_message_id or request_body is None:
            logger.error("Invalid SQS record (missing messageId or body): %s", record)
            continue

        request_context = parse_request_body(request_body)
        if request_context is None:
            logger.warning(
                "Skip invalid request message: message_id=%s", request_message_id
            )
            continue

        is_setup = is_setup_request(request_context["prompt"])
        if is_setup and bool(SETUP_LINKS_INVOCATION_URL):
            backend_type = "Setup"
        else:
            backend_type = "Agent"

        logger.info("Invoking %s API: message_id=%s", backend_type, request_message_id)
        try:
            backend_response = invoke_backend(request_context, backend_type)
        except Exception as e:
            logger.exception("Failed to invoke %s API: %s", backend_type, e)
            backend_response = {"response": "リクエストが失敗しました。"}

        if backend_response is None:
            batch_item_failures.append(
                {"itemIdentifier": request_message_id},
            )
            continue

        response_context = {
            "user_prompt": request_context["prompt"],
            "metadata": request_context["metadata"],
            **backend_response,
        }

        try:
            queue_response(
                response_context,
                request_message_id,
                message_group_id,
            )
            logger.info(
                "%s response queued: message_id=%s", backend_type, request_message_id
            )

        except Exception as e:
            logger.exception("Failed to queue %s response: %s", backend_type, e)
            batch_item_failures.append(
                {"itemIdentifier": request_message_id},
            )

    return {"batchItemFailures": batch_item_failures}


def parse_request_body(request_body: str) -> dict | None:
    try:
        data = json.loads(request_body)
    except json.JSONDecodeError:
        logger.error("Failed to parse request message as JSON")
        return None

    if not isinstance(data, dict):
        logger.error("Request message must be a JSON object")
        return None

    prompt = data.get("prompt")
    if not isinstance(prompt, str) or not prompt:
        logger.error("No prompt found in request message")
        return None

    metadata = data.get("metadata")
    if not isinstance(metadata, dict):
        logger.error("No metadata found in request message")
        return None

    return {
        "prompt": prompt,
        "metadata": metadata,
    }


def is_setup_request(user_prompt: str) -> bool:
    prompt = user_prompt.strip().casefold()
    normalized_prompt = "".join(
        chr(ord(char) + 0x60) if "ぁ" <= char <= "ゖ" else char for char in prompt
    )
    return normalized_prompt in {
        "setup",
        "セットアップ",
    }


def build_backend_request(
    backend_type: str, request_context: dict
) -> tuple[str, str, dict]:
    if backend_type == "Agent":
        return (
            AGENT_INVOCATION_URL,
            "bedrock-agentcore",
            {
                "prompt": request_context["prompt"],
            },
        )

    if backend_type == "Setup":
        return (
            SETUP_LINKS_INVOCATION_URL,
            "execute-api",
            {
                "prompt": request_context["prompt"],
                "metadata": request_context["metadata"],
            },
        )

    raise ValueError(f"Unknown backend_type: {backend_type}")


def invoke_backend(
    request_context: dict,
    backend_type: str,
) -> dict | None:
    (
        url,
        aws_service,
        payload,
    ) = build_backend_request(backend_type, request_context)
    request_body = json.dumps(payload).encode("utf-8")

    signed_request = AWSRequest(
        method="POST",
        url=url,
        data=request_body,
        headers={"Content-Type": "application/json"},
    )
    credentials = boto3.Session().get_credentials()
    if credentials is None:
        raise RuntimeError(
            f"AWS credentials are not available for {backend_type} API invocation"
        )

    region = os.environ.get("AWS_REGION")
    if not region:
        raise RuntimeError(f"AWS_REGION is not set for {backend_type} API invocation")

    SigV4Auth(
        credentials.get_frozen_credentials(),
        aws_service,
        region,
    ).add_auth(signed_request)
    prepared_request = signed_request.prepare()
    request = urllib.request.Request(
        prepared_request.url,
        data=prepared_request.body,
        headers=dict(prepared_request.headers.items()),
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=INVOCATION_TIMEOUT_SECONDS,
        ) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        with e:
            error_body = e.read().decode("utf-8", errors="replace")

        retryable_status = e.code in (
            HTTPStatus.REQUEST_TIMEOUT,
            HTTPStatus.TOO_MANY_REQUESTS,
            HTTPStatus.GATEWAY_TIMEOUT,
        )
        retryable_conflict = (
            aws_service == "bedrock-agentcore"
            and e.code == HTTPStatus.CONFLICT
            and e.headers.get("x-amzn-ErrorType", "").split(":", 1)[0]
            == "RetryableConflictException"
        )
        if retryable_status or retryable_conflict:
            logger.warning("Request will be retried: status=%s", e.code)
            return None

        logger.warning(
            "%s request rejected: status=%s, reason=%s, body=%s",
            backend_type,
            e.code,
            e.reason,
            error_body,
        )
        return {"response": "リクエストが失敗しました。"}

    try:
        queue_message = json.loads(response_body)
        return parse_backend_response(queue_message, backend_type)
    except (json.JSONDecodeError, RuntimeError) as e:
        logger.exception("Failed to read %s response: %s", backend_type, e)
        return {"response": "回答を受け取れませんでした。"}


def parse_backend_response(response_message: dict, backend_type: str) -> dict:
    if not isinstance(response_message, dict):
        raise RuntimeError(f"{backend_type} API response body is not an object")

    response = response_message.get("response")
    if not isinstance(response, str) or not response:
        raise RuntimeError(f"{backend_type} API response does not contain response")

    response_data = {"response": response}
    ai_disclosure = response_message.get("aiDisclosure")
    if ai_disclosure is not None:
        if not isinstance(ai_disclosure, str):
            raise RuntimeError(
                f"{backend_type} API response aiDisclosure is not a string"
            )
        response_data["aiDisclosure"] = ai_disclosure

    delivery = response_message.get("delivery")
    if delivery is not None:
        if not isinstance(delivery, dict):
            raise RuntimeError(f"{backend_type} API response delivery is not an object")
        response_data["delivery"] = delivery

    return response_data


def queue_response(
    queue_message: dict,
    request_message_id: str,
    request_message_group_id: str,
) -> None:
    # Generate message deduplication ID based on request message ID and response content
    message_deduplication_id = hashlib.sha256(
        f"{request_message_id}\0{queue_message['response']}".encode()
    ).hexdigest()

    sqs.send_message(
        QueueUrl=RESPONSE_QUEUE_URL,
        MessageBody=json.dumps(queue_message),
        MessageGroupId=request_message_group_id,
        MessageDeduplicationId=message_deduplication_id,
    )
