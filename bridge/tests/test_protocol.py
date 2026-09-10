import io
import json
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from protocol import CommandError, EventWriter, parse_command, to_display_coords, to_engine_coords


class TestCoordinates:
    """The app counts rows from the top, pysgf counts them from the bottom."""

    def test_top_left_corner(self):
        assert to_engine_coords(0, 0, 19) == (0, 18)
        assert to_display_coords((0, 18), 19) == {"row": 0, "col": 0}

    def test_bottom_right_corner(self):
        assert to_engine_coords(18, 18, 19) == (18, 0)
        assert to_display_coords((18, 0), 19) == {"row": 18, "col": 18}

    def test_round_trip_over_whole_board(self):
        for size in (9, 13, 19):
            for row in range(size):
                for col in range(size):
                    assert to_display_coords(to_engine_coords(row, col, size), size) == {"row": row, "col": col}

    def test_matches_gtp_naming(self):
        # Top-left of a 19x19 board is A19 in GTP; column 0, row 18 from the bottom.
        from pysgf import Move

        assert Move(coords=to_engine_coords(0, 0, 19)).gtp() == "A19"
        assert Move(coords=to_engine_coords(18, 0, 19)).gtp() == "A1"


class TestEventWriter:
    def test_one_json_object_per_line(self):
        stream = io.StringIO()
        writer = EventWriter(stream)
        writer.emit("state", 7, move_number=3)
        writer.emit("score", None, move_number=3, score_lead=1.5)
        lines = stream.getvalue().strip().split("\n")
        assert len(lines) == 2
        assert json.loads(lines[0]) == {"event": "state", "id": 7, "move_number": 3}
        assert json.loads(lines[1]) == {"event": "score", "id": None, "move_number": 3, "score_lead": 1.5}

    def test_payload_never_spans_lines(self):
        stream = io.StringIO()
        EventWriter(stream).emit("error", 1, message="broken\nover\nlines")
        assert len(stream.getvalue().strip().split("\n")) == 1


class TestParseCommand:
    def test_rejects_malformed_json(self):
        with pytest.raises(CommandError) as exc:
            parse_command("{not json")
        assert exc.value.code == "bad_json"

    def test_rejects_command_without_cmd(self):
        with pytest.raises(CommandError) as exc:
            parse_command('{"id": 1}')
        assert exc.value.code == "bad_command"

    def test_accepts_valid_command(self):
        assert parse_command('{"id": 1, "cmd": "play", "row": 3, "col": 4}')["cmd"] == "play"
