#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CHECKER = REPO_ROOT / "plugins/codex-loop-harness/scripts/check-codex-hook-after-update.py"


def write_fake_codex(path: Path, hooks_enabled: bool) -> None:
    path.write_text(
        """const args = process.argv.slice(2);
if (args.includes('--version')) {
  console.log('codex-cli 9.9.9');
} else if (args[0] === 'features' && args[1] === 'list') {
  console.log('hooks stable %s');
} else {
  process.exit(2);
}
""" % ("true" if hooks_enabled else "false"),
        encoding="utf-8",
    )


def invoke(root: Path, codex: Path, hook_test: Path, hook_mode: bool = False):
    requirements = root / "requirements.toml"
    hook_script = root / "goal-loop-bootstrap.py"
    requirements.write_text(
        f'hooks = true\n[[hooks.UserPromptSubmit]]\ncommand = "{hook_script}"\n',
        encoding="utf-8",
    )
    hook_script.write_text("# fixture\n", encoding="utf-8")
    command = [
        sys.executable,
        str(CHECKER),
        "--codex-real",
        str(codex),
        "--requirements",
        str(requirements),
        "--hook-script",
        str(hook_script),
        "--hook-test",
        str(hook_test),
        "--state-root",
        str(root / "state"),
    ]
    if hook_mode:
        command.append("--hook-mode")
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="codex-hook-update-") as temp:
        root = Path(temp)
        good_codex = root / "good-codex.js"
        bad_codex = root / "bad-codex.js"
        good_test = root / "good-test.py"
        write_fake_codex(good_codex, True)
        write_fake_codex(bad_codex, False)
        good_test.write_text('print("Goal loop hook test: OK")\n', encoding="utf-8")

        result = invoke(root, good_codex, good_test)
        require(result.returncode == 0 and result.stdout == "" and result.stderr == "", "passing check must be silent")
        require((root / "state/hook-check-version").is_file(), "passing check must record the version")

        result = invoke(root, good_codex, good_test)
        require(result.stdout == "" and result.stderr == "", "unchanged version must stay silent")

        (root / "state/hook-check-version").unlink()
        result = invoke(root, bad_codex, good_test, hook_mode=True)
        require("systemMessage" in result.stdout, "failed hook-mode check must warn the user")
        require("no longer reports" in result.stdout, "warning must identify hook incompatibility")

    print("Codex hook update check test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
