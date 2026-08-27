import base64
import gzip
import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ENDPOINT = os.environ["STATISTICS_LOGS_ENDPOINT"]
MAX_REQUEST_BYTES = 950_000
MAX_RECORDS_PER_BATCH = 500


def send_records(records):
    serialized_records = json.dumps(
        {"records": records},
        separators=(",", ":"),
    )
    payload = serialized_records.encode("utf-8")
    request = Request(
        ENDPOINT,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-transfer-to": "btm-tracis-statistics-api",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=10) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(
                    f"Statistics logs receiver rejected the request: "
                    f"status={response.status}"
                )
    except HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"Statistics logs forwarder request failed: "
            f"status={error.code}, body={error_body}"
        ) from error
    except URLError as error:
        raise RuntimeError(
            f"Statistics logs forwarder request failed: reason={error.reason}"
        ) from error


def create_record_batches(records):
    batch = []
    batch_size = len(b'{"records":[]}')

    for record in records:
        encoded = json.dumps(record, separators=(",", ":")).encode("utf-8")
        next_batch_size = batch_size + len(encoded) + 1

        if len(encoded) > MAX_REQUEST_BYTES:
            raise ValueError("Statistics log record is too large")

        if batch and (
            len(batch) >= MAX_RECORDS_PER_BATCH or next_batch_size > MAX_REQUEST_BYTES
        ):
            yield batch
            batch = []
            batch_size = len(b'{"records":[]}')

        batch.append(record)
        batch_size += len(encoded) + 1

    if batch:
        yield batch


def lambda_handler(event, _context):
    decompressed_payload = gzip.decompress(base64.b64decode(event["awslogs"]["data"]))
    payload = json.loads(decompressed_payload)
    owner = payload["owner"]
    records = []

    for event_record in payload.get("logEvents", []):
        message = json.loads(event_record["message"])

        if not isinstance(message, dict) or message.get("transfer_to") != "BTM":
            continue

        message["source_account_id"] = owner
        records.append(message)

    for batch in create_record_batches(records):
        send_records(batch)
