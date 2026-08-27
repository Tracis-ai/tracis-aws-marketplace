import logging
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus

from aws_lambda_powertools.utilities import parameters

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CHATWORK_API_BASE_URL = "https://api.chatwork.com/v2"
CHAT_TOOLS_SECRET_ARN = os.environ.get("CHAT_TOOLS_SECRET_ARN")
MAX_CHATWORK_MESSAGE_LENGTH = 65_500
CHATWORK_API_MAX_RETRY_COUNT = 3


def dispatch_response(message: dict) -> None:
    response = message.get("response")
    user_prompt = message.get("user_prompt")
    if not response:
        raise ValueError("response is missing")
    if not user_prompt:
        raise ValueError("user_prompt is missing")

    metadata = message.get("metadata") or {}
    room_id = metadata.get("room_id")
    message_id = metadata.get("message_id")
    from_account_id = metadata.get("from_account_id")
    send_time = metadata.get("send_time")
    if not (room_id and message_id and from_account_id):
        raise ValueError(
            "room_id, message_id, or from_account_id is missing for Chatwork response"
        )

    chatwork_api_token = get_chatwork_api_token()
    for message_part in build_chatwork_messages(
        response,
        user_prompt,
        room_id,
        message_id,
        from_account_id,
        send_time,
    ):
        send_with_chatwork_api(
            message=message_part,
            room_id=room_id,
            token=chatwork_api_token,
        )
    logger.info("Chatwork API response dispatched successfully")


def get_chatwork_api_token() -> str:
    if not CHAT_TOOLS_SECRET_ARN:
        logger.error("CHAT_TOOLS_SECRET_ARN is not set")
        raise ValueError("CHAT_TOOLS_SECRET_ARN is not set")

    secrets = parameters.get_secret(
        CHAT_TOOLS_SECRET_ARN,
        transform="json",
        max_age=300,
    )
    api_token = secrets.get("CHATWORK_API_TOKEN")
    if not api_token:
        raise ValueError("CHATWORK_API_TOKEN in secrets is missing or invalid")

    return api_token


def build_chatwork_messages(
    response: str,
    user_prompt: str,
    room_id: int | str,
    message_id: int | str,
    from_account_id: int | str,
    send_time: int | str | None,
) -> list[str]:
    reply_tag = f"[rp aid={from_account_id} to={room_id}-{message_id}]"
    quoted_user_prompt = (
        f"[qt][qtmeta aid={from_account_id}"
        f"{f' time={send_time}' if send_time else ''}]"
        f"{user_prompt}[/qt]"
    )
    text = f"{reply_tag}\n{quoted_user_prompt}\n\n{response}"

    return [
        text[i : i + MAX_CHATWORK_MESSAGE_LENGTH]
        for i in range(0, len(text), MAX_CHATWORK_MESSAGE_LENGTH)
    ]


def send_with_chatwork_api(
    message: str,
    room_id: int | str,
    token: str,
) -> None:
    url = f"{CHATWORK_API_BASE_URL}/rooms/{room_id}/messages"
    payload = {"body": message}
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-ChatworkToken": token,
    }

    request = urllib.request.Request(
        url,
        data=urllib.parse.urlencode(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    for retry_count in range(CHATWORK_API_MAX_RETRY_COUNT + 1):
        try:
            with urllib.request.urlopen(request):
                break
        except urllib.error.HTTPError as e:
            if (
                e.code != HTTPStatus.TOO_MANY_REQUESTS
                or retry_count >= CHATWORK_API_MAX_RETRY_COUNT
            ):
                raise

            reset_at = e.headers.get("x-ratelimit-reset")
            now = time.time()
            try:
                retry_after = max(int(reset_at) - int(now), 1) if reset_at else 10
            except ValueError:
                retry_after = 10

            logger.warning(
                "Chatwork API rate limited. Retrying after %s seconds.",
                retry_after,
            )
            time.sleep(retry_after)
