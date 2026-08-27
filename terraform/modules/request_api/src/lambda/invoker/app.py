import hashlib
import json
import logging
import os
import urllib.error
import urllib.request

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")

AGENT_INVOCATION_URL = os.environ.get("AGENT_INVOCATION_URL")
AGENT_INVOCATION_TIMEOUT_SECONDS = int(
    os.environ.get("AGENT_INVOCATION_TIMEOUT_SECONDS", "295")
)
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

        logger.info("Invoking Agent API: message_id=%s", request_message_id)
        try:
            response_text = invoke_agent(request_context)
        except Exception as e:
            logger.exception("Failed to invoke Agent API: %s", e)
            batch_item_failures.append(
                {"itemIdentifier": request_message_id},
            )
            continue

        queue_message = {
            "response": response_text,
            **request_context,
        }
        try:
            queue_response(
                queue_message,
                request_message_id,
                message_group_id,
            )
            logger.info("Agent response queued: message_id=%s", request_message_id)

        except Exception as e:
            logger.exception("Failed to queue Agent response: %s", e)
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
        "user_prompt": prompt,
        "metadata": metadata,
    }


def invoke_agent(request_context: dict) -> str:
    payload = {
        "prompt": request_context["user_prompt"],
    }
    request_body = json.dumps(payload).encode("utf-8")

    signed_request = AWSRequest(
        method="POST",
        url=AGENT_INVOCATION_URL,
        data=request_body,
        headers={"Content-Type": "application/json"},
    )
    credentials = boto3.Session().get_credentials()
    if credentials is None:
        raise RuntimeError("AWS credentials are not available for Agent invocation")

    region = os.environ.get("AWS_REGION")
    if not region:
        raise RuntimeError("AWS_REGION is not set for Agent invocation")

    SigV4Auth(
        credentials.get_frozen_credentials(),
        "bedrock-agentcore",
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
            timeout=AGENT_INVOCATION_TIMEOUT_SECONDS,
        ) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        raise RuntimeError(f"Agent API error: status={e.code}, body={error_body}")
    if not response_body:
        raise RuntimeError("Agent API response body is empty")

    try:
        queue_message = json.loads(response_body)
    except json.JSONDecodeError as e:
        raise RuntimeError("Agent API response body is not JSON") from e

    return parse_agent_response(queue_message)


def parse_agent_response(response_message: dict) -> str:
    if not isinstance(response_message, dict):
        raise RuntimeError("Agent API response body is not an object")

    response = response_message.get("response")
    if not response:
        raise RuntimeError("Agent API response does not contain response")

    return str(response)


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
