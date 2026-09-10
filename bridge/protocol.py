"""Wire format: coordinate conversion and event framing.

The app addresses intersections as (row, col) with row 0 at the top, the way the
board is drawn. pysgf addresses them as (col, row) with row 0 at the bottom. Every
conversion between the two conventions lives here, so no other module has to hold
both in its head at once.
"""

import json
import sys
import threading
from typing import Any, Dict, Optional, Tuple


def to_engine_coords(row: int, col: int, size: int) -> Tuple[int, int]:
    """Display (row from top, col) -> pysgf (col, row from bottom)."""
    return (col, size - 1 - row)


def to_display_coords(coords: Tuple[int, int], size: int) -> Dict[str, int]:
    """pysgf (col, row from bottom) -> display (row from top, col)."""
    col, row = coords
    return {"row": size - 1 - row, "col": col}


class EventWriter:
    """Writes events to stdout, one JSON object per line.

    Serialized behind a lock: analysis notifications arrive on KataGo's reader
    thread while the main thread may be answering a command, and two interleaved
    writes would produce a line the app cannot parse.
    """

    def __init__(self, stream=None):
        self._stream = stream if stream is not None else sys.stdout
        self._lock = threading.Lock()

    def emit(self, event: str, command_id: Optional[int] = None, **fields: Any) -> None:
        payload = {"event": event, "id": command_id}
        payload.update(fields)
        line = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        with self._lock:
            self._stream.write(line + "\n")
            self._stream.flush()


class CommandError(Exception):
    """A command that cannot be carried out, reported to the app as an error event."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def parse_command(line: str) -> Dict[str, Any]:
    try:
        command = json.loads(line)
    except json.JSONDecodeError as exc:
        raise CommandError("bad_json", str(exc)) from exc
    if not isinstance(command, dict):
        raise CommandError("bad_command", "command must be a JSON object")
    if "cmd" not in command:
        raise CommandError("bad_command", "command has no 'cmd' field")
    return command
