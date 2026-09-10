import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("KIVY_NO_ARGS", "1")
os.environ.setdefault("KIVY_NO_CONSOLELOG", "1")

import serialize
from katrain.core.game import Game
from protocol import to_engine_coords
from pysgf import Move


class FakeEngine:
    """Absorbs the analysis requests Game fires off on construction."""

    def __getattr__(self, name):
        return lambda *args, **kwargs: None


class FakeKaTrain:
    """The bare minimum Game reads off its katrain reference."""

    def __init__(self):
        self.game = None
        self.controls = FakeEngine()

    def log(self, message, level=0):
        pass

    def update_state(self, redraw_board=False):
        pass

    def config(self, path, default=None):
        return default


def make_game(size=9):
    katrain = FakeKaTrain()
    game = Game(katrain, FakeEngine(), game_properties={"SZ": size, "KM": 6.5, "RU": "japanese"})
    katrain.game = game
    return game


def play(game, row, col):
    size = serialize.board_size(game)
    player = game.current_node.next_player
    game.play(Move(coords=to_engine_coords(row, col, size), player=player))


class TestBoardSize:
    def test_square_board(self):
        assert serialize.board_size(make_game(9)) == 9

    def test_rejects_rectangular_board(self):
        game = make_game(9)
        game.root.set_property("SZ", "9:13")
        with pytest.raises(ValueError, match="non-square"):
            serialize.board_size(game)


class TestStones:
    def test_empty_board(self):
        assert serialize.stones(make_game()) == []

    def test_stone_keeps_its_displayed_position(self):
        game = make_game()
        play(game, 0, 0)
        assert serialize.stones(game) == [{"row": 0, "col": 0, "color": "B"}]

    def test_bottom_right_corner_is_not_mirrored(self):
        game = make_game()
        play(game, 8, 8)
        assert serialize.stones(game) == [{"row": 8, "col": 8, "color": "B"}]


class TestCaptures:
    """The core counts prisoners by captured colour; the payload counts by captor."""

    def test_black_capturing_a_white_stone(self):
        game = make_game()
        play(game, 0, 1)  # B, right of the corner
        play(game, 0, 0)  # W, into the corner
        play(game, 1, 0)  # B, below the corner: white has no liberties left
        assert serialize.captures(game) == {"by_black": 1, "by_white": 0}
        assert {(s["row"], s["col"]) for s in serialize.stones(game)} == {(0, 1), (1, 0)}

    def test_nothing_captured_yet(self):
        game = make_game()
        play(game, 4, 4)
        assert serialize.captures(game) == {"by_black": 0, "by_white": 0}


class TestLastMove:
    def test_none_on_empty_board(self):
        assert serialize.last_move(make_game()) is None

    def test_reports_the_move_just_played(self):
        game = make_game()
        play(game, 2, 6)
        assert serialize.last_move(game) == {"row": 2, "col": 6}

    def test_none_after_a_pass(self):
        game = make_game()
        game.play(Move(coords=None, player="B"))
        assert serialize.last_move(game) is None


class TestScoreHistory:
    def test_unanalysed_nodes_are_holes_not_zeros(self):
        game = make_game()
        play(game, 4, 4)
        play(game, 2, 2)
        history = serialize.score_history(game)
        assert len(history) == 3  # root plus two moves
        assert history == [None, None, None]


class TestGameState:
    def test_shape_of_a_fresh_game(self):
        state = serialize.game_state(make_game(), human_color="B")
        assert state["size"] == 9
        assert state["to_play"] == "B"
        assert state["move_number"] == 0
        assert state["status"] == "playing"
        assert state["result"] is None
        assert state["human_color"] == "B"

    def test_turn_alternates(self):
        game = make_game()
        play(game, 4, 4)
        state = serialize.game_state(game, human_color="B")
        assert state["to_play"] == "W"
        assert state["move_number"] == 1

    def test_resignation_ends_the_game(self):
        game = make_game()
        play(game, 4, 4)
        game.current_node.end_state = "B+R"
        state = serialize.game_state(game, human_color="B")
        assert state["status"] == "finished"
        assert state["result"] == "B+R"
