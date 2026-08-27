import json
import logging
import os
import re
import urllib.request

import boto3
from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")

PLATFORM = "slack"
SLACK_POST_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
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
    slack_bot_token = secrets.get("SLACK_BOT_TOKEN")
    if not slack_bot_token:
        logger.error("SLACK_BOT_TOKEN not found in secrets")
        raise ValueError("SLACK_BOT_TOKEN in secrets is missing or invalid")

    slack_event = event.get("event")
    if not slack_event:
        logger.error("Missing event payload")
        return

    channel = slack_event.get("channel")
    message_ts = slack_event.get("ts")
    if not (channel and message_ts):
        logger.error(
            "Missing required fields in event payload (channel, ts): %s",
            slack_event,
        )
        return

    try:
        thread_ts = slack_event.get("thread_ts") or message_ts
        text = slack_event.get("text", "")
        prompt = extract_prompt(text)

        queue_message = {
            "prompt": prompt,
            "metadata": {
                "platform": PLATFORM,
                "channel": channel,
                "thread_ts": thread_ts,
            },
        }
        dedup_id = f"{PLATFORM}:{channel}:{message_ts}"

        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(queue_message),
            MessageGroupId="default",
            MessageDeduplicationId=dedup_id,
        )
        logger.info("Message sent to SQS successfully")

        post_thread_reply_to_slack(
            channel=channel,
            thread_ts=thread_ts,
            text="✅ リクエストを受け付けました。しばらくお待ちください...",
            token=slack_bot_token,
        )
        logger.info("Thread reply posted successfully")

    except Exception as e:
        logger.exception(f"Error handling Slack request: {e}")
        raise


def extract_prompt(text: str) -> str:
    # remove mention tags
    extracted_text = re.sub(r"<@[^>]+>", "", text)

    return extracted_text.strip()


def post_thread_reply_to_slack(
    channel: str,
    thread_ts: str,
    text: str,
    token: str,
) -> None:
    payload = {
        "channel": channel,
        "thread_ts": thread_ts,
        "text": text,
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    request = urllib.request.Request(
        SLACK_POST_MESSAGE_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    with urllib.request.urlopen(request) as response:
        body = json.loads(response.read().decode("utf-8"))

    if not body.get("ok"):
        raise RuntimeError(f"Slack API error: {body}")
