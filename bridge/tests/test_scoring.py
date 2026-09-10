import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import scoring


def board(rows):
    """Builds a board from a picture: 'B' black, 'W' white, '.' empty."""
    stones = {}
    for row, line in enumerate(rows):
        for col, char in enumerate(line):
            if char in "BW":
                stones[(row, col)] = char
    return stones, len(rows)


class TestGroups:
    def test_single_stone(self):
        stones, size = board(["B..", "...", "..."])
        assert scoring.group_at(stones, size, (0, 0)) == {(0, 0)}

    def test_connected_stones_form_one_group(self):
        stones, size = board(["BB.", "B..", "..."])
        assert scoring.group_at(stones, size, (0, 0)) == {(0, 0), (0, 1), (1, 0)}

    def test_diagonals_are_not_connected(self):
        stones, size = board(["B..", ".B.", "..."])
        assert scoring.group_at(stones, size, (0, 0)) == {(0, 0)}

    def test_colours_do_not_mix(self):
        stones, size = board(["BW.", "...", "..."])
        assert scoring.group_at(stones, size, (0, 0)) == {(0, 0)}

    def test_empty_point_has_no_group(self):
        stones, size = board(["...", "...", "..."])
        assert scoring.group_at(stones, size, (1, 1)) == set()

    def test_all_groups_covers_every_stone_once(self):
        stones, size = board(["BB.", "..W", "W.."])
        groups = scoring.all_groups(stones, size)
        assert sorted(len(g) for g in groups) == [1, 1, 2]
        assert sum(len(g) for g in groups) == len(stones)


class TestTerritory:
    """A board split down the middle, each side holding two corners.

        . B W .
        B B W W
        B B W W
        . B W .
    """

    POSITION = [".BW.", "BBWW", "BBWW", ".BW."]

    def test_each_side_holds_its_corners(self):
        stones, size = board(self.POSITION)
        assert scoring.territory(stones, size) == {
            (0, 0): "B",
            (3, 0): "B",
            (0, 3): "W",
            (3, 3): "W",
        }

    def test_region_touching_both_colours_is_dame(self):
        stones, size = board(["B.W", "B.W", "B.W"])
        assert scoring.territory(stones, size) == {}

    def test_empty_board_belongs_to_nobody(self):
        stones, size = board(["...", "...", "..."])
        assert scoring.territory(stones, size) == {}

    def test_a_lone_colour_owns_everything_left(self):
        stones, size = board([".B.", "BB.", "..."])
        assert len(scoring.territory(stones, size)) == 6


class TestScore:
    POSITION = [".BW.", "BBWW", "BBWW", ".BW."]

    #: The same board with a white stone stranded in Black's top-left corner.
    WITH_DEAD_WHITE = ["WBW.", "BBWW", "BBWW", ".BW."]

    def test_japanese_counts_territory_and_prisoners(self):
        stones, size = board(self.POSITION)
        result = scoring.score(
            size, stones, dead=[], komi=0.5, captures={"by_black": 2, "by_white": 0}
        )
        assert result["territory"] == {"B": 2, "W": 2}
        assert result["black"] == 4  # two points of territory plus two prisoners
        assert result["white"] == 2.5
        assert result["result"] == "B+1.5"

    def test_dead_stones_become_territory_and_prisoners(self):
        stones, size = board(self.WITH_DEAD_WHITE)

        alive = scoring.score(size, stones, dead=[], komi=0, captures={"by_black": 0, "by_white": 0})
        assert alive["territory"] == {"B": 1, "W": 2}
        assert alive["result"] == "W+1"

        counted = scoring.score(
            size, stones, dead=[(0, 0)], komi=0, captures={"by_black": 0, "by_white": 0}
        )
        # The point it occupied, plus the stone itself as a prisoner.
        assert counted["territory"] == {"B": 2, "W": 2}
        assert counted["black"] == 3
        assert counted["result"] == "B+1"

    def test_komi_can_decide_the_game(self):
        stones, size = board(self.POSITION)
        result = scoring.score(size, stones, dead=[], komi=6.5, captures={"by_black": 0, "by_white": 0})
        assert result["result"] == "W+6.5"

    def test_a_drawn_game(self):
        stones, size = board(self.POSITION)
        result = scoring.score(size, stones, dead=[], komi=0, captures={"by_black": 0, "by_white": 0})
        assert result["result"] == "Draw"

    def test_chinese_counts_stones_and_ignores_prisoners(self):
        stones, size = board(self.POSITION)
        result = scoring.score(
            size, stones, dead=[], komi=0, captures={"by_black": 5, "by_white": 0}, rules="chinese"
        )
        assert result["black"] == 8  # six living stones plus two points
        assert result["white"] == 8
        assert result["result"] == "Draw"

    def test_marking_a_stone_dead_twice_over_is_harmless(self):
        stones, size = board(self.WITH_DEAD_WHITE)
        once = scoring.score(size, stones, dead=[(0, 0)], komi=0, captures={"by_black": 0, "by_white": 0})
        twice = scoring.score(
            size, stones, dead=[(0, 0), (0, 0), (3, 3)], komi=0, captures={"by_black": 0, "by_white": 0}
        )
        assert once["result"] == twice["result"]

    def test_territory_points_are_reported_for_display(self):
        stones, size = board(self.POSITION)
        result = scoring.score(size, stones, dead=[], komi=0, captures={"by_black": 0, "by_white": 0})
        assert result["points"] == [
            {"row": 0, "col": 0, "color": "B"},
            {"row": 0, "col": 3, "color": "W"},
            {"row": 3, "col": 0, "color": "B"},
            {"row": 3, "col": 3, "color": "W"},
        ]


class TestSuggestDead:
    def test_a_group_deep_in_enemy_territory_is_proposed(self):
        stones, size = board(["W..", "...", "..."])
        # Ownership is row-major from the top, positive for Black.
        ownership = [0.9] * 9
        assert scoring.suggest_dead(size, stones, ownership) == [(0, 0)]

    def test_a_group_in_its_own_area_is_left_alone(self):
        stones, size = board(["W..", "...", "..."])
        ownership = [-0.9] * 9
        assert scoring.suggest_dead(size, stones, ownership) == []

    def test_an_undecided_group_is_left_alone(self):
        stones, size = board(["W..", "...", "..."])
        ownership = [0.2] * 9
        assert scoring.suggest_dead(size, stones, ownership) == []

    def test_no_ownership_means_no_suggestion(self):
        stones, size = board(["W..", "...", "..."])
        assert scoring.suggest_dead(size, stones, None) == []
        assert scoring.suggest_dead(size, stones, [0.9, 0.9]) == []

    def test_whole_group_is_proposed_together(self):
        stones, size = board(["WW.", "W..", "..."])
        ownership = [0.9] * 9
        assert scoring.suggest_dead(size, stones, ownership) == [(0, 0), (0, 1), (1, 0)]
