"""Turn a KaTrain Game into the state payload the app renders.

Deliberately free of engine and process concerns: every function here takes a Game
and returns plain data, so the whole module can be tested against a game built by
hand with no KataGo running.
"""

from typing import Any, Dict, List, Optional

from protocol import to_display_coords


def board_size(game) -> int:
    """Side length of a square board.

    The milestone only supports square boards; a rectangular one would silently
    corrupt every coordinate conversion, so it is rejected loudly instead.
    """
    width, height = game.board_size
    if width != height:
        raise ValueError(f"non-square board {width}x{height} is not supported")
    return width


def stones(game) -> List[Dict[str, Any]]:
    size = board_size(game)
    placed = []
    for move in game.stones:
        placed.append({**to_display_coords(move.coords, size), "color": move.player})
    return placed


def score_history(game) -> List[Optional[float]]:
    """Score lead from Black's point of view, one entry per node from the root.

    Entries whose analysis has not come back yet are None; the app leaves those
    bars out rather than drawing them at zero.
    """
    return [node.score for node in game.current_node.nodes_from_root]


def captures(game) -> Dict[str, int]:
    """Stones captured by each player.

    The core counts prisoners by the colour of the captured stone, so the stones
    Black captured are the white ones. Naming the keys by the capturing player
    here keeps that inversion from leaking into the app.
    """
    prisoners = game.prisoner_count
    return {"by_black": prisoners["W"], "by_white": prisoners["B"]}


def last_move(game) -> Optional[Dict[str, int]]:
    move = game.current_node.move
    if move is None or move.is_pass:
        return None
    return to_display_coords(move.coords, board_size(game))


def game_state(game, human_color: str) -> Dict[str, Any]:
    node = game.current_node
    result = game.end_result
    return {
        "size": board_size(game),
        "stones": stones(game),
        "to_play": node.next_player,
        "move_number": node.depth,
        "last_move": last_move(game),
        "captures": captures(game),
        "score_history": score_history(game),
        "score_lead": node.score,
        "human_color": human_color,
        "status": "finished" if result else "playing",
        "result": result,
    }
