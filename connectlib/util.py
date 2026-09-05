from __future__ import annotations

import json
import sys


def emit(payload: dict) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def fail(message: str, **extra) -> None:
    payload = {"ok": False, "error": message}
    payload.update(extra)
    emit(payload)
    raise SystemExit(0)
