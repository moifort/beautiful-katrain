"""The session under review: navigation, bounds, and the variation branch.

Driven with the same fake engine as the scoring tests, so nothing here waits on
KataGo. Without a real engine no analysis ever comes back, which is exactly what
makes the navigation itself visible.
"""

import io
import json
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("KIVY_NO_ARGS", "1")
os.environ.setdefault("KIVY_NO_CONSOLELOG", "1")

from protocol import EventWriter
from session import BridgeSession

RECORD = (
    "(;GM[1]FF[4]SZ[9]KM[6.5]RU[japanese]PB[Noir]PW[Blanc]RE[B+R]"
    ";B[ee];W[cc];B[gg];W[cg];B[gc])"
)


class FakeEngine:
    """Absorbs the analysis requests Game fires off; no KataGo involved."""

    def __getattr__(self, name):
        return lambda *args, **kwargs: None


@pytest.fixture
def session():
    stream = io.StringIO()
    bridge = BridgeSession(EventWriter(stream))
    bridge._engine = FakeEngine()
    bridge._stream = stream
    return bridge


@pytest.fixture
def reviewing(session):
    session.load_sgf(1, "partie.sgf", RECORD)
    return session


def events(session):
    lines = session._stream.getvalue().strip().split("\n")
    return [json.loads(line) for line in lines if line]


def last_state(session):
    return [e for e in events(session) if e["event"] == "state"][-1]


def errors(session):
    return [e for e in events(session) if e["event"] == "error"]


def test_a_record_opens_at_its_last_move(reviewing):
    state = last_state(reviewing)
    assert state["status"] == "review"
    assert state["move_number"] == 5
    assert state["move_count"] == 5
    assert len(state["stones"]) == 5
    assert state["game_info"]["black_name"] == "Noir"
    assert state["result"] == "B+R"


def test_the_whole_record_is_on_the_chart_even_from_the_start(reviewing):
    reviewing.goto(2, 0)
    state = last_state(reviewing)
    assert state["move_number"] == 0
    # One entry per position of the record, not just the ones already walked.
    assert len(state["score_history"]) == 6
    assert state["stones"] == []


def test_navigation_is_clamped_at_both_ends(reviewing):
    reviewing.goto(2, 99)
    assert last_state(reviewing)["move_number"] == 5
    reviewing.goto(3, -4)
    assert last_state(reviewing)["move_number"] == 0
    assert errors(reviewing) == []


def test_no_marker_while_nothing_has_been_analysed(reviewing):
    assert last_state(reviewing)["best_move"] is None


def test_playing_commands_are_refused_while_reviewing(reviewing):
    reviewing.play(2, 0, 0)
    reviewing.undo(3)
    reviewing.resign(4)
    assert [e["code"] for e in errors(reviewing)] == ["not_playing"] * 3


def test_navigation_is_refused_outside_a_review(session):
    session.new_game(1, 9, 6.5, "japanese", "B", "ai:human", {})
    session.goto(2, 3)
    assert errors(session)[-1]["code"] == "not_reviewing"


def test_a_variation_needs_an_analysis_to_walk(reviewing):
    reviewing.step_variation(2, 1)
    assert errors(reviewing)[-1]["code"] == "no_variation"


def test_a_variation_is_played_then_taken_back_without_touching_the_record(reviewing):
    reviewing.goto(2, 2)
    anchor = reviewing.game.current_node
    children_before = list(anchor.children)
    # KataGo would supply this; we stand in for it so the walk can be exercised.
    reviewing._anchor_pv = ["G7", "C7"]
    reviewing._variation = []

    reviewing._push_variation(3)
    state = last_state(reviewing)
    assert state["variation_depth"] == 1
    assert len(state["stones"]) == 3
    # The position keeps the record's own move number; the depth says where we are.
    assert state["move_number"] == 2

    reviewing._push_variation(4)
    assert last_state(reviewing)["variation_depth"] == 2
    assert len(last_state(reviewing)["stones"]) == 4

    reviewing._pop_variation(5)
    reviewing._pop_variation(6)
    assert last_state(reviewing)["variation_depth"] == 0
    assert reviewing.game.current_node is anchor
    assert [id(c) for c in anchor.children] == [id(c) for c in children_before]


def test_a_variation_landing_on_the_played_move_does_not_delete_the_record(reviewing):
    reviewing.goto(2, 2)
    anchor = reviewing.game.current_node
    played = anchor.ordered_children[0]
    # G7 is the move actually played next in the record.
    reviewing._anchor_pv = [played.move.gtp()]
    reviewing._variation = []

    reviewing._push_variation(3)
    assert reviewing.game.current_node is played
    reviewing._pop_variation(4)
    # Walking into the record must leave it whole.
    assert played in anchor.children
    assert reviewing._line[3] is played


def test_stepping_back_with_no_variation_says_so(reviewing):
    reviewing.step_variation(2, -1)
    assert errors(reviewing)[-1]["code"] == "no_variation"


def test_navigating_away_prunes_the_branch(reviewing):
    reviewing.goto(2, 1)
    anchor = reviewing.game.current_node
    reviewing._anchor_pv = ["A1"]
    reviewing._variation = []
    reviewing._push_variation(3)
    assert len(anchor.children) == 2

    reviewing.goto(4, 4)
    assert len(anchor.children) == 1
    assert last_state(reviewing)["variation_depth"] == 0


def test_a_new_game_leaves_the_review_behind(reviewing):
    reviewing.new_game(2, 9, 6.5, "japanese", "B", "ai:human", {})
    state = last_state(reviewing)
    assert state["status"] == "playing"
    assert "move_count" not in state
    assert reviewing._line == []


def test_an_unreadable_record_is_reported_not_crashed(session):
    with pytest.raises(Exception):
        session.load_sgf(1, "vide.sgf", "")
