"""The pure side of a review: reading a record, the marker, the variation.

No engine anywhere. Analyses are written by hand, in the shape KataGo returns, so
these tests stay true whatever the machine is willing to compute.
"""

import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("KIVY_NO_ARGS", "1")
os.environ.setdefault("KIVY_NO_CONSOLELOG", "1")

import review
from protocol import CommandError

RECORD = (
    "(;GM[1]FF[4]SZ[19]KM[6.5]RU[japanese]"
    "PB[Shusaku]PW[Gennan]BR[4d]WR[8d]RE[B+2]DT[1846-07-21]EV[Ear-reddening]"
    ";B[qd];W[dp];B[oc];W[dd])"
)

BRANCHED = "(;GM[1]FF[4]SZ[9];B[ee](;W[cc];B[gg])(;W[gg]))"


def test_main_line_is_the_record_plus_its_root():
    root = review.parse(RECORD)
    assert review.move_count(root) == 4
    assert [node.depth for node in review.main_line(root)] == [0, 1, 2, 3, 4]


def test_branches_follow_the_first_child():
    root = review.parse(BRANCHED)
    assert review.move_count(root) == 3
    assert [node.move.gtp() for node in review.main_line(root)[1:]] == ["E5", "C7", "G3"]


def test_game_info_reads_the_record():
    info = review.game_info(review.parse(RECORD))
    assert info["black_name"] == "Shusaku"
    assert info["white_rank"] == "8d"
    assert info["result"] == "B+2"
    assert info["event"] == "Ear-reddening"


def test_game_info_says_none_rather_than_empty():
    info = review.game_info(review.parse("(;GM[1]FF[4]SZ[9];B[ee])"))
    assert info["black_name"] is None
    assert info["date"] is None


def test_empty_text_is_refused_as_bad_sgf():
    with pytest.raises(CommandError) as caught:
        review.parse("   ")
    assert caught.value.code == "bad_sgf"


def test_rectangular_board_is_refused_before_it_corrupts_coordinates():
    with pytest.raises(CommandError) as caught:
        review.parse("(;GM[1]FF[4]SZ[19:9];B[ee])")
    assert caught.value.code == "bad_sgf"
    assert "carr" in caught.value.message


def analysed(node, top="D4", points_lost=0.0, pv=("D4", "Q16", "C3")):
    """Fills a node with the parts of an analysis the review actually reads."""
    node.analysis = {
        "completed": True,
        "root": {"scoreLead": 0.0, "winrate": 0.5},
        "moves": {
            top: {
                "move": top,
                "order": 0,
                "scoreLead": 0.0,
                "winrate": 0.5,
                "visits": 100,
                "pv": list(pv),
            }
        },
    }
    return node


def test_best_move_converts_to_display_coordinates():
    root = review.parse("(;GM[1]FF[4]SZ[19];B[qd])")
    node = review.main_line(root)[0]
    analysed(node, top="D4")
    # D4 is the fourth column and the fourth line from the bottom: row 15 from the top.
    assert review.best_move(node, 19) == {"row": 15, "col": 3, "points_lost": 0.0}


def test_best_move_is_none_without_an_analysis():
    root = review.parse("(;GM[1]FF[4]SZ[19];B[qd])")
    assert review.best_move(review.main_line(root)[0], 19) is None


def test_a_pass_leaves_nothing_to_mark():
    root = review.parse("(;GM[1]FF[4]SZ[19];B[qd])")
    node = analysed(review.main_line(root)[0], top="pass", pv=("pass",))
    assert review.best_move(node, 19) is None


def test_variation_is_the_engine_continuation():
    root = review.parse("(;GM[1]FF[4]SZ[19];B[qd])")
    node = analysed(review.main_line(root)[0], pv=("D4", "Q16", "C3"))
    assert review.variation(node) == ["D4", "Q16", "C3"]


def test_variation_is_empty_without_an_analysis():
    root = review.parse("(;GM[1]FF[4]SZ[19];B[qd])")
    assert review.variation(review.main_line(root)[0]) == []


def test_progress_counts_the_main_line_only():
    root = review.parse(BRANCHED)
    line = review.main_line(root)
    assert review.progress(root) == {"done": 0, "total": 4}
    analysed(line[0])
    analysed(line[2])
    assert review.progress(root) == {"done": 2, "total": 4}
