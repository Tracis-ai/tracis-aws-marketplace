import json
import logging
from typing import Callable

import chatwork
import slack

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DISPATCHERS: dict[str, Callable[[dict], None]] = {
    "chatwork": chatwork.dispatch_response,
    "slack": slack.dispatch_response,
}


def lambda_handler(event, _):
    batch_item_failures = []

    for record in event.get("Records", []):
        queue_message_id = record["messageId"]

        try:
            message = json.loads(record["body"])
            metadata = message.get("metadata") or {}
            platform = metadata.get("platform")
            dispatcher = DISPATCHERS.get(platform)
            if not dispatcher:
                raise RuntimeError(f"Unsupported response platform: {platform}")

            logger.info(
                "Dispatching response: platform=%s message_id=%s",
                platform,
                queue_message_id,
            )

            dispatcher(message)
            logger.info(
                "Response dispatched: platform=%s message_id=%s",
                platform,
                queue_message_id,
            )

        except Exception as e:
            logger.exception("Failed to dispatch response: %s", e)
            batch_item_failures.append(
                {"itemIdentifier": queue_message_id},
            )

    return {"batchItemFailures": batch_item_failures}
