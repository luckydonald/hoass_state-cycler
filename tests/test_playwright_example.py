import os
import threading
import http.server
import socketserver
import tempfile
from pathlib import Path

import pytest
from playwright.sync_api import sync_playwright

# This test demonstrates using Playwright to open a simple HTTP page that
# contains a snapshot of a (mocked) Home Assistant state. It is a scaffold —
# replace with a real integration test that serves the Home Assistant UI or
# proxies the real frontend for full end-to-end checks.

RUN_PLAYWRIGHT = os.getenv("RUN_PLAYWRIGHT", "0") == "1"

# Mark as a Playwright test so Makefile/CI can run it in isolation to avoid
# event-loop conflicts between pytest-asyncio and Playwright's fixtures.
pytestmark = [
    pytest.mark.playwright,
    pytest.mark.skipif(not RUN_PLAYWRIGHT, reason="Playwright tests disabled"),
]


def _start_file_server(directory: Path, port: int):
    handler = http.server.SimpleHTTPRequestHandler
    # Change working directory for the handler
    class CWDHandler(handler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(directory), **kwargs)

    httpd = socketserver.TCPServer(("127.0.0.1", port), CWDHandler)

    def serve():
        httpd.serve_forever()

    t = threading.Thread(target=serve, daemon=True)
    t.start()
    return httpd


def _write_snapshot_page(directory: Path, entity_id: str, friendly: str) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    p = directory / "index.html"
    content = f"""
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>State Cycler Playwright Test</title>
      </head>
      <body>
        <h1 id="entity">{entity_id}</h1>
        <div id="friendly">{friendly}</div>
      </body>
    </html>
    """
    p.write_text(content)
    return p


def test_playwright_sees_state():
    """A minimal smoke test using Playwright's sync API.

    This test does NOT start Home Assistant — it demonstrates how to use
    Playwright in CI to validate a page that contains a snapshot of HA state.
    Using the sync API avoids pytest-playwright's async fixtures and thus
    prevents asyncio event-loop conflicts with pytest-asyncio fixtures.
    """
    # Prepare a simple HTML page that displays a mocked hass entity
    tmp = Path(tempfile.mkdtemp(prefix="playwright-test-"))
    entity_id = "light.kitchen"
    friendly = "Kitchen Lights"
    _write_snapshot_page(tmp, entity_id, friendly)

    # Start a simple static file server serving that directory
    server = _start_file_server(tmp, 8765)

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto("http://127.0.0.1:8765/index.html")
            # Basic assertions that the page shows expected content
            content = page.text_content("#friendly")
            assert friendly in content
            eid = page.text_content("#entity")
            assert entity_id in eid
            browser.close()
    finally:
        server.shutdown()
