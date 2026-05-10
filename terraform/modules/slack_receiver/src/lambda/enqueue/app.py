import json
import logging
import os
import re
import urllib.request
import uuid

import boto3
from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")

SLACK_POST_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
SLACK_SECRET_ARN = os.environ.get("SLACK_SECRET_ARN")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")

if not SLACK_SECRET_ARN:
    logger.error("SLACK_SECRET_ARN is not set")
    raise ValueError("SLACK_SECRET_ARN is not set")

if not SQS_QUEUE_URL:
    logger.error("SQS_QUEUE_URL is not set")
    raise ValueError("SQS_QUEUE_URL is not set")


def lambda_handler(event, context):
    # Slack Bot Token 取得
    secrets = parameters.get_secret(
        SLACK_SECRET_ARN,
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
    thread_ts = slack_event.get("thread_ts") or slack_event.get("ts")
    if not channel or not thread_ts:
        logger.error(
            "Missing channel or thread timestamp (thread_ts or ts): %s", slack_event
        )
        return

    try:
        text = slack_event.get("text", "")
        prompt = re.sub(r"<@[^>]+>", "", text).strip()

        queue_message = {
            "prompt": prompt,
            "channel": channel,
            "thread_ts": thread_ts,
        }

        dedup_id = event.get("event_id") or str(
            uuid.uuid5(
                uuid.NAMESPACE_URL,
                json.dumps(queue_message, sort_keys=True),
            )
        )

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

    request = urllib.request.Request(
        SLACK_POST_MESSAGE_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    with urllib.request.urlopen(request) as response:
        body = json.loads(response.read().decode("utf-8"))

    if not body.get("ok"):
        raise RuntimeError(f"Slack API error: {body}")
