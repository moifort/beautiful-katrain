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
    run(session, session.load_sgf, 1, "partie.sgf", RECORD)
    return session


def run(session, method, *args):
    """Goes through the worker's own error policy, as a real command would."""
    session.run_task(method, *args)


def analysed(node, pv):
    """Stands in for KataGo: the parts of an analysis a review actually reads."""
    node.analysis = {
        "completed": True,
        "root": {"scoreLead": 0.0, "winrate": 0.5},
        "moves": {
            pv[0]: {
                "move": pv[0],
                "order": 0,
                "scoreLead": 0.0,
                "winrate": 0.5,
                "visits": 100,
                "pv": list(pv),
            }
        },
    }
    return node


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
    run(reviewing, reviewing.goto, 2, 0)
    state = last_state(reviewing)
    assert state["move_number"] == 0
    # One entry per position of the record, not just the ones already walked.
    assert len(state["score_history"]) == 6
    assert state["stones"] == []


def test_navigation_is_clamped_at_both_ends(reviewing):
    run(reviewing, reviewing.goto, 2, 99)
    assert last_state(reviewing)["move_number"] == 5
    run(reviewing, reviewing.goto, 3, -4)
    assert last_state(reviewing)["move_number"] == 0
    assert errors(reviewing) == []


def test_no_marker_while_nothing_has_been_analysed(reviewing):
    assert last_state(reviewing)["best_move"] is None


def test_playing_commands_are_refused_while_reviewing(reviewing):
    run(reviewing, reviewing.play, 2, 0, 0)
    run(reviewing, reviewing.undo, 3)
    run(reviewing, reviewing.resign, 4)
    assert [e["code"] for e in errors(reviewing)] == ["not_playing"] * 3


def test_navigation_is_refused_outside_a_review(session):
    run(session, session.new_game, 1, 9, 6.5, "japanese", "B", "ai:human", {})
    run(session, session.goto, 2, 3)
    assert errors(session)[-1]["code"] == "not_reviewing"


def test_a_variation_needs_an_analysis_to_walk(reviewing):
    run(reviewing, reviewing.step_variation, 2, 1)
    assert errors(reviewing)[-1]["code"] == "no_variation"


def test_a_variation_is_played_then_taken_back_without_touching_the_record(reviewing):
    run(reviewing, reviewing.goto, 2, 2)
    anchor = reviewing.game.current_node
    children_before = list(anchor.children)
    analysed(anchor, ["A1", "A9"])

    run(reviewing, reviewing.step_variation, 3, 1)
    state = last_state(reviewing)
    assert state["variation_depth"] == 1
    assert len(state["stones"]) == 3
    # The position keeps the record's own move number; the depth says where we are.
    assert state["move_number"] == 2

    run(reviewing, reviewing.step_variation, 4, 1)
    assert last_state(reviewing)["variation_depth"] == 2
    assert len(last_state(reviewing)["stones"]) == 4

    run(reviewing, reviewing.step_variation, 5, -1)
    run(reviewing, reviewing.step_variation, 6, -1)
    assert last_state(reviewing)["variation_depth"] == 0
    assert reviewing.game.current_node is anchor
    assert [id(c) for c in anchor.children] == [id(c) for c in children_before]


def test_a_variation_landing_on_the_played_move_does_not_delete_the_record(reviewing):
    run(reviewing, reviewing.goto, 2, 2)
    anchor = reviewing.game.current_node
    played = anchor.ordered_children[0]
    # The engine's first choice is the move the record actually plays next.
    analysed(anchor, [played.move.gtp()])

    run(reviewing, reviewing.step_variation, 3, 1)
    assert reviewing.game.current_node is played
    run(reviewing, reviewing.step_variation, 4, -1)
    # Walking into the record must leave it whole.
    assert played in anchor.children
    assert reviewing._line[3] is played


def test_stepping_back_with_no_variation_says_so(reviewing):
    run(reviewing, reviewing.step_variation, 2, -1)
    assert errors(reviewing)[-1]["code"] == "no_variation"


def test_navigating_away_prunes_the_branch(reviewing):
    run(reviewing, reviewing.goto, 2, 1)
    anchor = reviewing.game.current_node
    analysed(anchor, ["A1"])
    run(reviewing, reviewing.step_variation, 3, 1)
    assert len(anchor.children) == 2

    run(reviewing, reviewing.goto, 4, 4)
    assert len(anchor.children) == 1
    assert last_state(reviewing)["variation_depth"] == 0


def test_a_new_game_leaves_the_review_behind(reviewing):
    run(reviewing, reviewing.new_game, 2, 9, 6.5, "japanese", "B", "ai:human", {})
    state = last_state(reviewing)
    assert state["status"] == "playing"
    assert "move_count" not in state
    assert reviewing._line == []


def test_an_unreadable_record_is_reported_not_crashed(session):
    run(session, session.load_sgf, 1, "vide.sgf", "")
    assert errors(session)[-1]["code"] == "bad_sgf"


def test_a_deepening_analysis_lets_the_walk_go_further(reviewing):
    """The first press often sees a one-move line; the walk must not freeze there."""
    run(reviewing, reviewing.goto, 2, 2)
    anchor = reviewing.game.current_node
    analysed(anchor, ["A1"])

    run(reviewing, reviewing.step_variation, 3, 1)
    assert last_state(reviewing)["variation_depth"] == 1

    # KataGo keeps pondering and comes back with a longer line from the same move.
    analysed(anchor, ["A1", "A9", "B1"])
    run(reviewing, reviewing.step_variation, 4, 1)
    assert last_state(reviewing)["variation_depth"] == 2
    assert errors(reviewing) == []


def test_a_line_that_disagrees_with_the_board_is_not_adopted(reviewing):
    """A refined analysis that changes its first move must not rewrite the branch."""
    run(reviewing, reviewing.goto, 2, 2)
    anchor = reviewing.game.current_node
    analysed(anchor, ["A1"])
    run(reviewing, reviewing.step_variation, 3, 1)

    # A different first move: the walk keeps the line already on the board.
    analysed(anchor, ["B1", "B9", "C1"])
    run(reviewing, reviewing.step_variation, 4, 1)
    assert errors(reviewing)[-1]["code"] == "no_variation"
    assert last_state(reviewing)["variation_depth"] == 1
