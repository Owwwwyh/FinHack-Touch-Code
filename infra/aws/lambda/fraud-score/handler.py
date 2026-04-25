"""
AWS Lambda: fraud-score
Per docs/05-aws-services.md §4.

Geo/velocity heuristics for fraud detection on settled tokens.
"""

import json
import math
import os
import time


def handler(event, context):
    """Score a transaction for fraud risk."""
    detail = event.get("detail", event)
    tx_id = detail.get("tx_id", "unknown")
    sender_lat = detail.get("sender_lat")
    sender_lon = detail.get("sender_lon")
    receiver_lat = detail.get("receiver_lat")
    receiver_lon = detail.get("receiver_lon")
    iat = detail.get("iat", 0)
    amount_cents = detail.get("amount_cents", 0)

    flags = []
    risk_score = 0.0

    # Geo-distance check (if both locations available)
    if sender_lat and sender_lon and receiver_lat and receiver_lon:
        distance_km = haversine(sender_lat, sender_lon, receiver_lat, receiver_lon)
        if distance_km > 500:  # More than 500km
            flags.append("GEO_IMPOSSIBLE")
            risk_score += 0.5

    # Amount velocity check
    global_cap_cents = int(os.environ.get("GLOBAL_CAP_CENTS", "25000"))
    if amount_cents > global_cap_cents:
        flags.append("AMOUNT_OVER_CAP")
        risk_score += 0.8

    # Time-based check
    if iat > 0:
        now = int(time.time())
        if now - iat > 72 * 3600:  # Older than 72 hours
            flags.append("STALE_TOKEN")
            risk_score += 0.2

    risk_score = min(1.0, risk_score)

    return {
        "tx_id": tx_id,
        "risk_score": risk_score,
        "flags": flags,
        "action": "REVIEW" if risk_score >= 0.5 else "ALLOW",
    }


def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance between two points in km."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))
