"""Le shim doit permettre d'importer katrain.core sans le vrai Kivy.

Le test tourne dans un sous-processus : une fois le vrai Kivy importé dans
l'interpréteur courant, on ne peut plus prouver qu'il ne l'était pas.
"""

import subprocess
import sys
from pathlib import Path

BRIDGE = Path(__file__).resolve().parent.parent
SHIMS = BRIDGE / "shims"

PROBE = """
import sys, json
import kivy
from katrain.core.ai import generate_ai_move
from katrain.core.engine import KataGoEngine
from katrain.core.game import Game
from katrain.core.base_katrain import KaTrainBase
print(json.dumps({
    "kivy_file": kivy.__file__,
    "loaded": sorted(m for m in sys.modules if m.split(".")[0] in ("kivy", "pygame", "ffpyplayer")),
}))
"""


def _run_probe():
    result = subprocess.run(
        [sys.executable, "-c", PROBE],
        capture_output=True,
        text=True,
        env={"PYTHONPATH": str(SHIMS), "PATH": "/usr/bin:/bin", "HOME": "/tmp"},
    )
    assert result.returncode == 0, f"la sonde a échoué :\n{result.stderr}"
    return json.loads(result.stdout.strip().splitlines()[-1])


def test_katrain_core_imports_with_only_the_shim():
    assert str(SHIMS) in _run_probe()["kivy_file"]


def test_no_real_kivy_pygame_or_ffpyplayer_is_loaded():
    loaded = _run_probe()["loaded"]
    assert not [m for m in loaded if m.startswith(("pygame", "ffpyplayer"))], loaded


import json  # noqa: E402  (utilisé par _run_probe, importé après le docstring pour la lisibilité)
