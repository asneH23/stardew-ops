"""
webhook_handler.py — GitHub Webhook HMAC-verifiering
GitHub signerar varje webhook med HMAC-SHA256 med din secret.
Vi verifierar signaturen INNAN vi processar payloaden.
"""

import hashlib
import hmac
import os
from fastapi import HTTPException, Request


WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")


async def verify_github_signature(request: Request) -> bytes:
    """
    Verifierar X-Hub-Signature-256 headern från GitHub.
    Returnerar raw body om giltig, kastar 401 annars.
    Om GITHUB_WEBHOOK_SECRET inte är satt (lokal dev), skippar vi verifiering.
    """
    body = await request.body()

    if not WEBHOOK_SECRET:
        # Lokal dev utan secret — tillåt, men logga varning
        print("⚠️  VARNING: GITHUB_WEBHOOK_SECRET inte satt. Skippar signaturverifiering.")
        return body

    signature_header = request.headers.get("X-Hub-Signature-256", "")
    if not signature_header.startswith("sha256="):
        raise HTTPException(status_code=401, detail="Saknad eller felaktig signatur-header")

    received_sig = signature_header[7:]  # ta bort "sha256="
    expected_sig = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(received_sig, expected_sig):
        raise HTTPException(status_code=401, detail="Ogiltig webhook-signatur")

    return body


def parse_push_event(payload: dict) -> dict | None:
    """
    Extraherar relevant data från en GitHub push-event payload.
    Returnerar None om payloaden inte är en push med commits.
    """
    commits = payload.get("commits", [])
    if not commits:
        return None

    # Vi tar det senaste commit:et
    latest = commits[-1]
    ref = payload.get("ref", "refs/heads/main")
    branch = ref.replace("refs/heads/", "")

    return {
        "sha": latest.get("id", "unknown"),
        "message": latest.get("message", ""),
        "branch": branch,
        "repo": payload.get("repository", {}).get("full_name", "unknown"),
        "author": latest.get("author", {}).get("name", "unknown"),
        "url": latest.get("url", ""),
    }
