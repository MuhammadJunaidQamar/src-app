"""Simple WebSocket relay server for forwarding CanSat telemetry packets.

Run this script on a reachable host and point the desktop client to it by
setting the ``CANSAT_WS_URL`` environment variable (defaults to
``ws://localhost:8765/telemetry``).  Any client that connects to this relay on
the same path will receive every packet sent by the publisher.
"""

import argparse
import asyncio
import logging
import os
from typing import Any, List, Optional, Set
from urllib.parse import urlsplit

try:
    import websockets  # type: ignore
    from websockets.exceptions import ConnectionClosed  # type: ignore
except ImportError as exc:  # pragma: no cover - explicit failure for missing dependency
    raise SystemExit(
        "The 'websockets' package is required. Install with 'pip install websockets'."
    ) from exc


def _normalise_path(path: Optional[str]) -> Optional[str]:
    """Return a canonicalised WebSocket path or ``None`` to accept any path."""

    if path is None:
        return None

    trimmed = str(path).strip()
    if trimmed in {"", "*"}:
        return None

    if "://" in trimmed:
        parsed = urlsplit(trimmed)
        trimmed = parsed.path or "/"

    if "?" in trimmed:
        trimmed = trimmed.split("?", 1)[0]
    if "#" in trimmed:
        trimmed = trimmed.split("#", 1)[0]

    if not trimmed.startswith("/"):
        trimmed = "/" + trimmed

    trimmed = trimmed.rstrip("/")
    return trimmed or "/"


class RelayServer:
    """Broadcasts any message received from one client to all others."""

    def __init__(self, allowed_path: Optional[str] = None) -> None:
        self.allowed_path = _normalise_path(allowed_path)
        self._clients: Set[Any] = set()
        self._lock = asyncio.Lock()
        self._logger = logging.getLogger("cansat.websocket.relay")

    @staticmethod
    def _format_address(websocket: Any) -> str:
        host, port = websocket.remote_address or ("?", "?")
        return f"{host}:{port}"

    async def register(self, websocket: Any) -> None:
        async with self._lock:
            self._clients.add(websocket)
        self._logger.info("Client connected: %s", self._format_address(websocket))

    async def unregister(self, websocket: Any) -> None:
        async with self._lock:
            self._clients.discard(websocket)
        self._logger.info("Client disconnected: %s", self._format_address(websocket))

    async def handler(
        self,
        websocket: Any,
        path: Optional[str] = None,
    ) -> None:
        """Process one WebSocket connection.

        ``websockets`` < 11 passes ``path`` as a second argument, whereas newer
        versions expose it on ``websocket.path``.  Supporting both keeps this
        relay compatible across releases.
        """

        if path is None:
            path = getattr(websocket, "path", None)

        requested_path = _normalise_path(path)
        self._logger.info(
            "Incoming connection %s path=%r (normalised=%r, allowed=%r)",
            self._format_address(websocket),
            path,
            requested_path,
            self.allowed_path or "*",
        )
        if self.allowed_path and requested_path not in {self.allowed_path, None}:
            self._logger.warning(
                "Rejecting %s on unexpected path '%s'",
                self._format_address(websocket),
                requested_path,
            )
            await websocket.close(code=1008, reason="Unsupported path")
            return

        await self.register(websocket)

        try:
            async for message in websocket:
                await self.broadcast(message, sender=websocket)
        except ConnectionClosed:
            pass
        finally:
            await self.unregister(websocket)

    async def broadcast(self, message: str, sender: Optional[Any] = None) -> None:
        async with self._lock:
            recipients = [ws for ws in self._clients if ws is not sender]

        if not recipients:
            return

        stale: List[Any] = []
        for ws in recipients:
            try:
                await ws.send(message)
            except (ConnectionClosed, Exception) as e:
                self._logger.debug("Failed to send to client %s: %s", self._format_address(ws), e)
                stale.append(ws)

        if stale:
            async with self._lock:
                for ws in stale:
                    self._clients.discard(ws)


async def _run_server(host: str, port: int, path: Optional[str], ping_interval: float) -> None:
    relay = RelayServer(path)
    logger = logging.getLogger("cansat.websocket.relay")
    display_path = relay.allowed_path or "*"
    path_fragment = "" if display_path == "*" else display_path
    logger.info("Starting relay on ws://%s:%d%s", host, port, path_fragment)

    async with websockets.serve(
        relay.handler,
        host,
        port,
        ping_interval=ping_interval,
        ping_timeout=ping_interval * 2,
    ):
        logger.info("Relay ready (path=%s)", display_path)
        await asyncio.Future()


def _parse_args() -> argparse.Namespace:
    # Check for cloud platform PORT environment variable
    default_port = int(os.environ.get("PORT", "8765"))
    
    parser = argparse.ArgumentParser(description="Forward telemetry frames to all connected WebSocket clients")
    parser.add_argument("--host", default="0.0.0.0", help="Interface to bind (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=default_port, help=f"Port to listen on (default: {default_port}, from PORT env var if set)")
    parser.add_argument(
        "--path",
        default="/telemetry",
        help="WebSocket path to accept (default: /telemetry, use '*' to accept any)",
    )
    parser.add_argument(
        "--ping",
        type=float,
        default=20.0,
        help="Ping interval in seconds for keep-alives (default: 20)",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging verbosity",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    try:
        asyncio.run(_run_server(args.host, args.port, args.path, args.ping))
    except KeyboardInterrupt:
        logging.getLogger("cansat.websocket.relay").info("Shutting down relay")


if __name__ == "__main__":
    main()

