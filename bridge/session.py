"""Headless KaTrain session driving a game against the AI.

Everything that touches the KaTrain core happens on a single worker thread. The
core notifies progress by calling `update_state()` from KataGo's reader thread; if
we generated the AI move right there, that thread would block waiting for the very
analyses it is supposed to be reading. KaTrain solves this with a message loop, and
so do we: `update_state()` only enqueues, the worker does the work.
"""

import os
import queue
import sys
import threading
from typing import Any, Dict, Optional

os.environ.setdefault("KIVY_NO_ARGS", "1")
os.environ.setdefault("KIVY_NO_CONSOLELOG", "1")

from katrain.core.ai import generate_ai_move
from katrain.core.base_katrain import KaTrainBase
from katrain.core.constants import OUTPUT_ERROR, PLAYER_AI, PLAYER_HUMAN, PLAYING_NORMAL
from katrain.core.engine import KataGoEngine
from katrain.core.game import Game, IllegalMoveException
from pysgf import Move

import serialize
from protocol import CommandError, to_engine_coords


class _Inert:
    """Swallows any attribute access, call or assignment.

    The core reaches into `katrain.controls` on the teaching and editing paths
    without checking whether a UI is attached. Returning something inert keeps
    those paths from raising in a headless process.
    """

    __slots__ = ()

    def __call__(self, *args, **kwargs):
        return None

    def __getattr__(self, name):
        return _INERT

    def __setattr__(self, name, value):
        pass

    def __bool__(self):
        return False


_INERT = _Inert()


class NullControls:
    """Stands in for the Kivy controls object, logging what the core reaches for.

    Each attribute name is reported once on stderr. An unexpected name showing up
    means the core took a path we have not accounted for, which is worth knowing
    even though nothing breaks.
    """

    def __init__(self, log):
        object.__setattr__(self, "_log", log)
        object.__setattr__(self, "_seen", set())

    def __getattr__(self, name):
        seen = object.__getattribute__(self, "_seen")
        if name not in seen:
            seen.add(name)
            object.__getattribute__(self, "_log")(f"core reached for controls.{name}")
        return _INERT

    def __setattr__(self, name, value):
        pass


class BridgeSession(KaTrainBase):
    """Owns the game state and mediates every call into the KaTrain core."""

    def __init__(self, writer):
        self._writer = writer
        self._tasks: "queue.Queue" = queue.Queue()
        self._engine: Optional[KataGoEngine] = None
        self._human_color = "B"
        self._emitted_scores: Dict[int, float] = {}
        self._ai_pending = False
        self._stopping = False
        super().__init__()
        self.controls = NullControls(self._log_stderr)

    # -- logging -------------------------------------------------------------
    # The base class prints to stdout, which is the protocol channel. Everything
    # diagnostic goes to stderr instead.

    def _log_stderr(self, message: str) -> None:
        sys.stderr.write(f"{message}\n")
        sys.stderr.flush()

    def log(self, message, level=1):
        if level == OUTPUT_ERROR or self.debug_level >= level:
            self._log_stderr(str(message))

    # -- worker loop ---------------------------------------------------------

    def start(self) -> None:
        self._worker = threading.Thread(target=self._run, daemon=True, name="bridge-worker")
        self._worker.start()

    def submit(self, fn, *args) -> None:
        self._tasks.put((fn, args))

    def _run(self) -> None:
        while True:
            fn, args = self._tasks.get()
            if fn is None:
                return
            try:
                fn(*args)
            except CommandError as exc:
                # Every command method takes its command id first, so the error can
                # be attributed to the command that caused it.
                self._writer.emit("error", args[0] if args else None, code=exc.code, message=exc.message)
            except Exception as exc:  # keep the bridge alive; the app sees the error
                self._writer.emit("error", None, code="internal", message=f"{type(exc).__name__}: {exc}")
                self._log_stderr(f"worker error: {type(exc).__name__}: {exc}")

    def stop(self) -> None:
        self._stopping = True
        self._tasks.put((None, ()))
        if self._engine is not None:
            try:
                self._engine.shutdown(finish=False)
            except Exception:
                pass

    # -- engine --------------------------------------------------------------

    def start_engine(self) -> None:
        self._engine = KataGoEngine(self, self.config("engine"))

    # -- state notification --------------------------------------------------

    def update_state(self, redraw_board=False):
        """Called by the core whenever an analysis advances. Never does work here."""
        if not self._stopping:
            self.submit(self._on_state_advanced)

    def _on_state_advanced(self) -> None:
        if self.game is None:
            return
        self._emit_new_scores()
        self._maybe_play_ai_move()

    #: Score changes smaller than this are not worth an event. KataGo keeps refining
    #: an analysis while it ponders, and without a threshold every node would emit a
    #: stream of events differing in the third decimal.
    SCORE_EPSILON = 0.05

    def _emit_new_scores(self) -> None:
        for node in self.game.current_node.nodes_from_root:
            if not node.analysis_complete:
                continue
            score = node.score
            if score is None:
                continue
            previous = self._emitted_scores.get(node.depth)
            if previous is not None and abs(previous - score) < self.SCORE_EPSILON:
                continue
            self._emitted_scores[node.depth] = score
            self._writer.emit("score", None, move_number=node.depth, score_lead=round(score, 2))

    def _maybe_play_ai_move(self) -> None:
        """Reproduces the core's own trigger condition for an AI move.

        Mirrors katrain/__main__.py: the AI only moves once the current node's
        analysis is complete, it is the AI's turn, nothing has been played on top,
        and the game has not ended.
        """
        node = self.game.current_node
        if not self._ai_pending:
            return
        if not (node.analysis_complete and not node.children and not self.game.end_result):
            return
        if not self.players_info[node.next_player].ai:
            return
        self._ai_pending = False
        strategy = self.players_info[node.next_player].strategy
        settings = self.config(f"ai/{strategy}")
        if settings is None:
            self._writer.emit("error", None, code="unknown_ai", message=f"AI strategy {strategy} not found")
            self._emit_state()
            return
        generate_ai_move(self.game, strategy, settings)
        self._writer.emit("thinking", None, value=False)
        self._emit_state()

    # -- commands ------------------------------------------------------------

    def _emit_state(self, command_id: Optional[int] = None) -> None:
        self._writer.emit("state", command_id, **serialize.game_state(self.game, self._human_color))

    def _size(self) -> int:
        return serialize.board_size(self.game)

    def new_game(self, command_id, size, komi, rules, human_color, ai_strategy, ai_settings):
        if self._engine is None:
            raise CommandError("no_engine", "engine not started")
        self._human_color = human_color
        ai_color = "W" if human_color == "B" else "B"
        self.players_info[human_color].update(PLAYER_HUMAN, PLAYING_NORMAL)
        self.players_info[ai_color].update(PLAYER_AI, ai_strategy)
        if ai_settings:
            self.config(f"ai/{ai_strategy}").update(ai_settings)
        self._emitted_scores.clear()
        self.game = Game(self, self._engine, game_properties={"SZ": size, "KM": komi, "RU": rules})
        self._ai_pending = self.players_info[self.game.current_node.next_player].ai
        if self._ai_pending:
            self._writer.emit("thinking", None, value=True)
        self._emit_state(command_id)

    def play(self, command_id, row, col):
        self._require_game()
        node = self.game.current_node
        if self.players_info[node.next_player].ai:
            raise CommandError("not_your_turn", "it is the AI's turn")
        move = Move(coords=to_engine_coords(row, col, self._size()), player=node.next_player)
        try:
            self.game.play(move)
        except IllegalMoveException as exc:
            raise CommandError("illegal_move", str(exc)) from exc
        self._after_human_move(command_id)

    def play_pass(self, command_id):
        self._require_game()
        node = self.game.current_node
        if self.players_info[node.next_player].ai:
            raise CommandError("not_your_turn", "it is the AI's turn")
        self.game.play(Move(coords=None, player=node.next_player))
        self._after_human_move(command_id)

    def _after_human_move(self, command_id) -> None:
        self._emit_state(command_id)
        if self.game.end_result:
            return
        self._ai_pending = self.players_info[self.game.current_node.next_player].ai
        if self._ai_pending:
            self._writer.emit("thinking", None, value=True)
            self._maybe_play_ai_move()

    def undo(self, command_id):
        """Steps back until it is the human's turn again, two moves in the usual case."""
        self._require_game()
        self._ai_pending = False
        steps = 0
        while steps < 2 and self.game.current_node.parent is not None:
            self.game.undo(1)
            steps += 1
            if self.players_info[self.game.current_node.next_player].human:
                break
        self._emitted_scores.clear()
        self._writer.emit("thinking", None, value=False)
        self._emit_state(command_id)

    def resign(self, command_id):
        self._require_game()
        self._ai_pending = False
        self.game.current_node.end_state = f"{self.game.current_node.next_player}+R"
        self._writer.emit("thinking", None, value=False)
        self._emit_state(command_id)

    def state(self, command_id):
        self._require_game()
        self._emit_state(command_id)

    def _require_game(self) -> None:
        if self.game is None:
            raise CommandError("no_game", "no game in progress")
