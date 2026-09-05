from __future__ import annotations


def parse_notification(nid, props: dict | None) -> dict:
    data = props or {}
    reply_id = str(data.get("replyId") or "")
    title = str(data.get("title") or "")
    text = str(data.get("text") or "")
    ticker = str(data.get("ticker") or "")
    app_name = str(data.get("appName") or "")
    return {
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
