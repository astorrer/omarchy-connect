from __future__ import annotations


def parse_message(raw) -> dict | None:
    if raw is None:
        return None
    if isinstance(raw, dict):
        body = str(raw.get("body") or "")
        addresses = [str(item) for item in (raw.get("addresses") or [])]
        return {
            "event": int(raw.get("event") or 0),
            "body": body,
            "addresses": addresses,
            "date": int(raw.get("date") or 0),
            "type": int(raw.get("type") or 0),
            "read": int(raw.get("read") or 0),
            "threadId": int(raw.get("threadId") or 0),
            "id": int(raw.get("id") or 0),
            "fromMe": bool(raw.get("fromMe")),
            "attachmentCount": int(raw.get("attachmentCount") or 0),
        }
    if not isinstance(raw, (list, tuple)) or len(raw) < 8:
        return None
    addresses = []
    for item in raw[2] or []:
        if isinstance(item, (list, tuple)) and item:
            addresses.append(str(item[0]))
        else:
            addresses.append(str(item))
    unique = []
    for address in addresses:
        if address and address not in unique:
            unique.append(address)
    msg_type = int(raw[4] or 0)
    attachments = raw[9] if len(raw) > 9 else []
    return {
        "event": int(raw[0] or 0),
        "body": str(raw[1] or ""),
        "addresses": unique,
        "date": int(raw[3] or 0),
        "type": msg_type,
        "read": int(raw[5] or 0),
        "threadId": int(raw[6] or 0),
        "id": int(raw[7] or 0),
        "fromMe": msg_type == 2,
        "attachmentCount": len(attachments or []),
    }
