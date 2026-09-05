from __future__ import annotations

import re

SMS_APP_NAMES = {
    "messages",
    "google messages",
    "messaging",
    "samsung messages",
    "textra",
    "qksms",
    "pulse",
    "pulse sms",
}


def is_sms_notification(item: dict | None) -> bool:
    name = " ".join(str((item or {}).get("appName") or "").split()).strip().lower()
    if not name:
        return False
    if name in SMS_APP_NAMES:
        return True
    return bool(re.search(r"\bsms\b", name))


def parse_notification(nid, props: dict | None) -> dict:
    data = props or {}
    reply_id = str(data.get("replyId") or "")
    title = str(data.get("title") or "")
    text = str(data.get("text") or "")
    ticker = str(data.get("ticker") or "")
    app_name = str(data.get("appName") or "")
    parsed = {
        "id": str(nid),
        "appName": app_name,
        "title": title,
        "text": text,
        "ticker": ticker,
        "silent": bool(data.get("silent")),
        "dismissable": bool(data.get("dismissable")),
        "canReply": reply_id != "",
        "replyId": reply_id,
        "isConversation": bool(data.get("isConversation")),
        "hasIcon": bool(data.get("hasIcon")),
    }
    parsed["sms"] = is_sms_notification(parsed)
    return parsed
