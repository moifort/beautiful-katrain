"""Entry point: reads commands on stdin, writes events on stdout.

stdout carries the protocol and nothing else. Diagnostics go to stderr, including
anything the KaTrain core would otherwise print.
"""

import sys
from typing import Any, Dict

from protocol import CommandError, EventWriter, parse_command
from session import BridgeSession


def _dispatch(session: BridgeSession, writer: EventWriter, command: Dict[str, Any]) -> bool:
    """Runs one command. Returns False when the bridge should shut down."""
    name = command["cmd"]
    command_id = command.get("id")

    if name == "quit":
        return False
    if name == "new_game":
        session.submit(
            session.new_game,
            command_id,
            int(command.get("size", 19)),
            float(command.get("komi", 6.5)),
            command.get("rules", "japanese"),
            command.get("human_color", "B"),
            command.get("ai_strategy", "ai:human"),
            command.get("ai_settings") or {},
        )
    elif name == "play":
        session.submit(session.play, command_id, int(command["row"]), int(command["col"]))
    elif name == "pass":
        session.submit(session.play_pass, command_id)
    elif name == "undo":
        session.submit(session.undo, command_id)
    elif name == "resign":
        session.submit(session.resign, command_id)
    elif name == "toggle_dead":
        session.submit(session.toggle_dead, command_id, int(command["row"]), int(command["col"]))
    elif name == "accept_score":
        session.submit(session.accept_score, command_id)
    elif name == "resume_game":
        session.submit(session.resume_game, command_id)
    elif name == "state":
        session.submit(session.state, command_id)
    else:
        raise CommandError("unknown_command", f"unknown command '{name}'")
    return True


def main() -> int:
    writer = EventWriter()
    session = BridgeSession(writer)
    session.start()

    try:
        session.start_engine()
    except Exception as exc:
        writer.emit("engine_failed", None, message=f"{type(exc).__name__}: {exc}")
        return 1

    writer.emit("ready", None, katago=session.config("engine/katago"), model=session.config("engine/model"))

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            command = parse_command(line)
        except CommandError as exc:
            writer.emit("error", None, code=exc.code, message=exc.message)
            continue
        try:
            if not _dispatch(session, writer, command):
                break
        except CommandError as exc:
            writer.emit("error", command.get("id"), code=exc.code, message=exc.message)
        except (KeyError, TypeError, ValueError) as exc:
            writer.emit("error", command.get("id"), code="bad_arguments", message=str(exc))

    session.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
