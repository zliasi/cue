#!/usr/bin/env python3
"""Regenerate tests/expected/*.slurm from the current renderer.

Review the diff before committing: the goldens are the specification of
the generated scripts.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from unittest import mock

TESTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS_DIR.parent))
sys.path.insert(0, str(TESTS_DIR))

# cue is a single file, not an installed package, so the path inserts
# above must run before these imports.
import cue  # noqa: E402
import test_cue  # noqa: E402


def main() -> int:
    expected_dir = TESTS_DIR / "expected"
    expected_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        os.chdir(tmp)
        with mock.patch.dict(
            os.environ,
            {cue.CONFIG_PATH_ENV: str(test_cue.CONFIG_DIR)},
        ):
            for name, argv, files in test_cue.GOLDEN_CASES:
                for file in files:
                    Path(file).parent.mkdir(parents=True, exist_ok=True)
                    Path(file).write_text("")
                code, stdout, stderr = test_cue.run_cue(argv)
                if code != 0:
                    print(f"{name}: FAILED\n{stderr}", file=sys.stderr)
                    return 1
                (expected_dir / f"{name}.slurm").write_text(stdout)
                print(f"wrote {name}.slurm")
    return 0


if __name__ == "__main__":
    sys.exit(main())
