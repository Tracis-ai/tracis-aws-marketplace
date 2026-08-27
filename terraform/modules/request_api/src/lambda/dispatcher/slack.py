import json
import logging
import os
import time
import urllib.error
import urllib.request
from http import HTTPStatus

from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SLACK_POST_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
CHAT_TOOLS_SECRET_ARN = os.environ.get("CHAT_TOOLS_SECRET_ARN")
MAX_SLACK_MESSAGE_LENGTH = 3000
SLACK_API_MAX_RETRY_COUNT = 3


def dispatch_response(message: dict) -> None:
    response = message.get("response")
    user_prompt = message.get("user_prompt")
    if not response:
        raise ValueError("response is missing")
    if not user_prompt:
        raise ValueError("user_prompt is missing")

    metadata = message.get("metadata") or {}
    channel = metadata.get("channel")
    thread_ts = metadata.get("thread_ts")
    if not channel or not thread_ts:
        raise ValueError("channel or thread_ts is missing for Slack response")

    slack_bot_token = get_slack_bot_token()
    for message_part in build_slack_messages(response, user_prompt):
        send_with_slack_api(
            message=message_part,
            channel=channel,
            thread_ts=thread_ts,
            token=slack_bot_token,
        )
    logger.info("Slack API response dispatched successfully")


def get_slack_bot_token() -> str:
    if not CHAT_TOOLS_SECRET_ARN:
        logger.error("CHAT_TOOLS_SECRET_ARN is not set")
        raise ValueError("CHAT_TOOLS_SECRET_ARN is not set")

    secrets = parameters.get_secret(
        CHAT_TOOLS_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    slack_bot_token = secrets.get("SLACK_BOT_TOKEN")
    if not slack_bot_token:
        raise ValueError("SLACK_BOT_TOKEN in secrets is missing or invalid")

    return slack_bot_token


def build_slack_messages(response: str, user_prompt: str) -> list[str]:
    response_text = response.replace("**", "*")
    quoted_user_prompt = "\n".join(f">{line}" for line in user_prompt.splitlines())
    text = f"{quoted_user_prompt}\n\n{response_text}"

    return [
        text[i : i + MAX_SLACK_MESSAGE_LENGTH]
        for i in range(0, len(text), MAX_SLACK_MESSAGE_LENGTH)
    ]


def send_with_slack_api(
    message: str,
    channel: str,
    thread_ts: str,
    token: str,
) -> None:
    payload = {
        "channel": channel,
        "thread_ts": thread_ts,
        "text": message,
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

    for retry_count in range(SLACK_API_MAX_RETRY_COUNT + 1):
        try:
            with urllib.request.urlopen(request) as response:
                response_body = json.loads(response.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as e:
            if (
                e.code != HTTPStatus.TOO_MANY_REQUESTS
                or retry_count >= SLACK_API_MAX_RETRY_COUNT
            ):
                raise

            try:
                retry_after = int(e.headers.get("Retry-After", "1"))
            except ValueError:
                retry_after = 1

            logger.warning(
                "Slack API rate limited. Retrying after %s seconds.",
                retry_after,
            )
            time.sleep(retry_after)

    if not response_body.get("ok"):
        raise RuntimeError(f"Slack API error: {response_body}")
