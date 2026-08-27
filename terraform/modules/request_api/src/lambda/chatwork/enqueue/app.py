import json
import logging
import os
import re
import urllib.error
import urllib.parse
import urllib.request

import boto3
from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")

PLATFORM = "chatwork"
CHATWORK_API_BASE_URL = "https://api.chatwork.com/v2"
CHAT_TOOLS_SECRET_ARN = os.environ.get("CHAT_TOOLS_SECRET_ARN")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")

if not CHAT_TOOLS_SECRET_ARN:
    logger.error("CHAT_TOOLS_SECRET_ARN is not set")
    raise ValueError("CHAT_TOOLS_SECRET_ARN is not set")

if not SQS_QUEUE_URL:
    logger.error("SQS_QUEUE_URL is not set")
    raise ValueError("SQS_QUEUE_URL is not set")


def lambda_handler(event, _):
    secrets = parameters.get_secret(
        CHAT_TOOLS_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    api_token = secrets.get("CHATWORK_API_TOKEN")
    if not api_token:
        logger.error("CHATWORK_API_TOKEN not found in secrets")
        raise ValueError("CHATWORK_API_TOKEN in secrets is missing or invalid")

    event_type = event.get("webhook_event_type")
    if event_type != "mention_to_me":
        logger.warning("Ignoring event type: %s", event_type)
        return

    chatwork_event = event.get("webhook_event")
    if not chatwork_event:
        logger.error("Missing event payload")
        return

    room_id = chatwork_event.get("room_id")
    message_id = chatwork_event.get("message_id")
    from_account_id = chatwork_event.get("from_account_id")
    if not (room_id and message_id and from_account_id):
        logger.error(
            "Missing required fields in event payload (room_id, message_id, from_account_id): %s",
            chatwork_event,
        )
        return

    try:
        send_time = chatwork_event.get("send_time")
        text = chatwork_event.get("body", "")
        prompt = extract_prompt(text)

        queue_message = {
            "prompt": prompt,
            "metadata": {
                "platform": PLATFORM,
                "room_id": room_id,
                "message_id": message_id,
                "from_account_id": from_account_id,
                "send_time": send_time,
            },
        }
        dedup_id = f"{PLATFORM}:{room_id}:{message_id}"

        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(queue_message),
            MessageGroupId="default",
            MessageDeduplicationId=dedup_id,
        )
        logger.info("Message sent to SQS successfully")

        ack_text = (
            f"[rp aid={from_account_id} to={room_id}-{message_id}]\n"
            "✅ リクエストを受け付けました。しばらくお待ちください..."
        )
        post_message(
            room_id=room_id,
            text=ack_text,
            api_token=api_token,
        )
        logger.info("Reply posted successfully")

    except Exception as e:
        logger.exception(f"Error handling Chatwork request: {e}")
        raise


def extract_prompt(text: str) -> str:
    # remove mention tags
    extracted_text = re.sub(r"\[To:\d+\][^\n]*\n?", "", text)
    # remove reply tags
    extracted_text = re.sub(r"\[rp aid=\d+ to=\d+-\S+\]\n?", "", extracted_text)

    return extracted_text.strip()


def post_message(room_id: int, text: str, api_token: str) -> None:
    url = f"{CHATWORK_API_BASE_URL}/rooms/{room_id}/messages"
    payload = {"body": text}
    headers = {
        "x-chatworktoken": api_token,
        "Content-Type": "application/x-www-form-urlencoded",
    }

    request = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(request):
            pass
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        raise RuntimeError(f"Chatwork API error: status={e.code}, body={error_body}")
