"""Le shim chardet doit suffire à pysgf, sans embarquer de LGPL."""

import subprocess
import sys
from pathlib import Path

BRIDGE = Path(__file__).resolve().parent.parent
SHIMS = BRIDGE / "shims"

PROBE = """
import chardet
from pysgf import BaseGoGame, Move
print(chardet.__file__)
print(chardet.detect("bonjour".encode("utf-8"))["encoding"])
print(chardet.detect(b"\\xe9\\xe8\\xea")["encoding"])
"""


def _probe():
    result = subprocess.run(
        [sys.executable, "-c", PROBE],
        capture_output=True,
        text=True,
        env={"PYTHONPATH": str(SHIMS), "PATH": "/usr/bin:/bin", "HOME": "/tmp"},
    )
    assert result.returncode == 0, f"la sonde a échoué :\n{result.stderr}"
    return result.stdout.strip().splitlines()


def test_pysgf_imports_against_the_shim():
    path, _, _ = _probe()
    assert str(SHIMS) in path


def test_detect_distinguishes_utf8_from_eight_bit_bytes():
    _, utf8, latin1 = _probe()
    assert utf8 == "utf-8"
    assert latin1 == "ISO-8859-1"
