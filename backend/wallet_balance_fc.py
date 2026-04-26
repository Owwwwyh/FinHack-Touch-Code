"""Alibaba FC entrypoint for wallet balance."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fc.wallet_balance.handler import handler as _wsgi_handler
from fc_http_adapter import invoke_wsgi_handler


def handler(event, context):  # noqa: ANN001
    return invoke_wsgi_handler(_wsgi_handler, event, context)
