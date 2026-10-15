"""
Engine tests for bin/cue.

Unit tests call the engine functions directly. Golden tests run the command
line in a temporary copy of tests/fixtures with a fake sbatch on PATH and
compare the rendered script with tests/expected. CUE_UPDATE_GOLDENS=1
rewrites the expected files instead, which is what make goldens does.
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import os
import shutil
import stat
import sys
import tempfile
import unittest
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures"
EXPECTED = ROOT / "tests" / "expected"
STAMP = "20261015-160000"
LATER_STAMP = "20261015-160100"
JOB_ID = "12345"

FAKE_SBATCH = """\
#!/usr/bin/env bash
printf '%s\\n' "$@" > "$FAKE_SBATCH_ARGS"
if [ "$1" = --test-only ]; then
  echo "sbatch: Job 999 to start now" >&2
  exit 0
fi
if [ -n "$FAKE_SBATCH_FAIL" ]; then
  echo "sbatch: error: invalid partition" >&2
  exit 1
fi
echo "{job};steno"
"""


def load_engine() -> ModuleType:
    """Import bin/cue, which has no .py suffix, as a module."""
    loader = importlib.machinery.SourceFileLoader("cue", str(ROOT / "bin" / "cue"))
    spec = importlib.util.spec_from_loader("cue", loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    # Dataclasses resolve postponed annotations through sys.modules.
    sys.modules[spec.name] = module
    loader.exec_module(module)
    return module


cue = load_engine()


class SettingsTest(unittest.TestCase):
    """Config files, header parsing, and precedence."""

    def setUp(self) -> None:
        env = {
            "CUE_HOME": str(FIXTURES / "home"),
            "XDG_CONFIG_HOME": str(FIXTURES / "xdg"),
        }
        patch = mock.patch.dict(os.environ, env)
        patch.start()
        self.addCleanup(patch.stop)
        self.orca = FIXTURES / "home" / "templates" / "orca.sbatch"

    def test_header_reads_every_cue_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.sbatch"
            path.write_text("#!/bin/bash\n#CUE a=1 b=x\n#SBATCH -n 1\n#CUE c=3\n")
            self.assertEqual(cue.read_header(path), {"a": "1", "b": "x", "c": "3"})

    def test_header_rejects_bare_token(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.sbatch"
            path.write_text("#CUE cpus\n")
            with self.assertRaises(cue.UserError) as caught:
                cue.read_header(path)
            self.assertIn(f"{path}:1", str(caught.exception))

    def test_conf_ignores_blank_and_comment_lines(self) -> None:
        self.assertEqual(
            cue.read_conf(FIXTURES / "home" / "cue.conf"),
            {"partition": "chem", "throttle": "10", "outdir": "out", "logdir": "log"},
        )

    def test_conf_missing_file_is_empty(self) -> None:
        self.assertEqual(cue.read_conf(FIXTURES / "nowhere.conf"), {})

    def test_precedence_site_user_header_flags(self) -> None:
        settings = cue.resolve_settings(self.orca, {"memory": "32"})
        self.assertEqual(settings["partition"], "chem")
        self.assertEqual(settings["throttle"], "4")
        self.assertEqual(settings["cpus"], "8")
        self.assertEqual(settings["memory"], "32")
        self.assertEqual(settings["ext"], ".inp")

    def test_invalid_values_are_rejected(self) -> None:
        for flags in (
            {"cpus": "0"},
            {"memory": "16G"},
            {"time": "tomorrow"},
            {"gpu": "one"},
            {"name": "../x"},
        ):
            with self.subTest(flags=flags), self.assertRaises(cue.UserError):
                cue.resolve_settings(self.orca, flags)


class RenderTest(unittest.TestCase):
    """Placeholder substitution."""

    def test_substitutes_every_placeholder(self) -> None:
        text = "{{a}} and {{b}} and {{a}}"
        self.assertEqual(cue.render(text, {"a": "1", "b": "2"}), "1 and 2 and 1")

    def test_shell_syntax_passes_through(self) -> None:
        text = 'x=${var} y="$CUE_INPUT" z=$(date) {a}'
        self.assertEqual(cue.render(text, {}), text)

    def test_missing_placeholders_are_listed_sorted(self) -> None:
        with self.assertRaises(cue.UserError) as caught:
            cue.render("{{zeta}} {{alpha}} {{known}}", {"known": "1"})
        self.assertEqual(
            str(caught.exception),
            "no value for alpha, zeta, set it in cue.conf or with --set",
        )

    def test_strip_header_keeps_other_lines(self) -> None:
        text = "#!/bin/bash\n#CUE a=1\n#SBATCH -n 1\necho\n"
        self.assertEqual(cue.strip_header(text), "#!/bin/bash\n#SBATCH -n 1\necho\n")


class InputTest(unittest.TestCase):
    """Manifests, input validation, and skip-done."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)

    def test_manifest_skips_blank_and_comment_lines(self) -> None:
        self.assertEqual(cue.read_manifest(FIXTURES / "list.txt"), ["w1.sh", "w2.sh"])

    def test_manifest_without_inputs_fails(self) -> None:
        path = self.dir / "empty.txt"
        path.write_text("# nothing\n\n")
        with self.assertRaises(cue.UserError) as caught:
            cue.read_manifest(path)
        self.assertIn("no inputs", str(caught.exception))

    def test_manifest_must_exist(self) -> None:
        with self.assertRaises(cue.UserError):
            cue.read_manifest(self.dir / "missing.txt")

    def test_inputs_need_extension_and_file(self) -> None:
        (self.dir / "a.inp").write_text("")
        cue.validate_inputs([str(self.dir / "a.inp")], ".inp")
        with self.assertRaises(cue.UserError):
            cue.validate_inputs([str(self.dir / "a.inp")], ".com")
        with self.assertRaises(cue.UserError):
            cue.validate_inputs([str(self.dir / "b.inp")], ".inp")

    def test_stem_drops_last_extension_only(self) -> None:
        self.assertEqual(cue.stem_of("in/h2o.opt.inp"), "h2o.opt")
        self.assertEqual(cue.stem_of("Makefile"), "Makefile")

    def test_done_path_is_relative_to_outdir(self) -> None:
        self.assertEqual(
            cue.done_path("{{stem}}.out", "in/a.inp", "out"), Path("out/a.out")
        )
        self.assertEqual(cue.done_path("/abs/{{stem}}", "a.inp", "out"), Path("/abs/a"))

    def test_drop_done_keeps_inputs_without_done_file(self) -> None:
        out = self.dir / "out"
        out.mkdir()
        (out / "a.out").write_text("")
        settings = {"done": "{{stem}}.out", "outdir": str(out)}
        self.assertEqual(cue.drop_done(["a.inp", "b.inp"], settings), ["b.inp"])

    def test_drop_done_needs_pattern(self) -> None:
        with self.assertRaises(cue.UserError) as caught:
            cue.drop_done(["a.inp"], {"outdir": "out"})
        self.assertIn("done pattern", str(caught.exception))


class CommandTest(unittest.TestCase):
    """The command line in a fixture copy with a fake sbatch on PATH."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        shutil.copytree(FIXTURES, self.dir, dirs_exist_ok=True)
        bin_dir = self.dir / "bin"
        bin_dir.mkdir()
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(FAKE_SBATCH.format(job=JOB_ID))
        sbatch.chmod(sbatch.stat().st_mode | stat.S_IXUSR)
        self.args_file = self.dir / "sbatch.args"
        env = {
            "CUE_HOME": "home",
            "XDG_CONFIG_HOME": "xdg",
            "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
            "FAKE_SBATCH_ARGS": str(self.args_file),
            "FAKE_SBATCH_FAIL": "",
        }
        for patch in (
            mock.patch.dict(os.environ, env),
            mock.patch.object(cue.time, "strftime", return_value=STAMP),
            mock.patch.object(cue.time, "sleep"),
        ):
            patch.start()
            self.addCleanup(patch.stop)
        previous = os.getcwd()
        os.chdir(self.dir)
        self.addCleanup(os.chdir, previous)

    def run_cue(self, argv: Sequence[str]) -> tuple[int, str, str]:
        """Run cue in-process, return status, stdout, and stderr."""
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = cue.main(list(argv))
        return status, out.getvalue(), err.getvalue()

    def sbatch_args(self) -> list[str]:
        return self.args_file.read_text().splitlines()

    def assert_golden(self, name: str, text: str) -> None:
        """Compare TEXT with tests/expected/NAME.sbatch, or rewrite it."""
        path = EXPECTED / (name + ".sbatch")
        if os.environ.get("CUE_UPDATE_GOLDENS"):
            path.write_text(text)
            return
        self.assertEqual(text, path.read_text(), f"{path} differs, see make goldens")

    def test_defaults_render_submit_and_record(self) -> None:
        status, out, err = self.run_cue(["orca", "a.inp", "b.inp"])
        self.assertEqual((status, out, err), (0, JOB_ID + "\n", ""))
        script = Path("log") / f"orca-{STAMP}.sbatch"
        self.assert_golden("orca-defaults", script.read_text())
        self.assertEqual(
            self.sbatch_args(), ["--parsable", "--comment=cue:orca", str(script)]
        )
        self.assertEqual(
            Path(f"log/orca-{STAMP}.manifest").read_text(), "a.inp\nb.inp\n"
        )
        self.assertEqual(
            Path(f"log/orca-{JOB_ID}.cue").read_text(),
            f"# resubmit with: cue -f log/orca-{JOB_ID}.cue\n"
            f"template=orca\nmanifest=log/orca-{STAMP}.manifest\n"
            f"job={JOB_ID}\nstamp={STAMP}\n",
        )
        self.assertTrue(Path("out").is_dir())

    def test_flags_override_every_setting(self) -> None:
        argv = ["orca", "-c", "16", "-m", "32", "-t", "2-00:00:00", "-p", "gpu"]
        argv += ["-T", "1", "-j", "batch1", "-o", "results", "-l", "logs", "c.inp"]
        status, out, err = self.run_cue(argv)
        self.assertEqual((status, err), (0, ""))
        script = Path("logs") / f"batch1-{STAMP}.sbatch"
        self.assert_golden("orca-flags", script.read_text())
        self.assertIn("--comment=cue:batch1", self.sbatch_args())
        record = Path(f"logs/batch1-{JOB_ID}.cue").read_text()
        self.assertIn("cpus=16\nlogdir=logs\nmemory=32\nname=batch1\n", record)

    def test_manifest_set_and_gpu_render(self) -> None:
        argv = ["run", "-M", "list.txt", "-n", "4", "--gpu", "--set", "cpus=2"]
        argv += ["--after", "100"]
        status, out, err = self.run_cue(argv)
        self.assertEqual((status, err), (0, ""))
        self.assert_golden("run-manifest", Path(f"log/run-{STAMP}.sbatch").read_text())
        self.assertEqual(
            Path(f"log/run-{STAMP}.manifest").read_text(), "w1.sh\nw2.sh\n"
        )
        self.assertIn("--dependency=afterok:100", self.sbatch_args())

    def test_record_resubmits_the_same_script(self) -> None:
        argv = ["orca", "-c", "16", "-m", "32", "-t", "2-00:00:00", "-p", "gpu"]
        argv += ["-T", "1", "-j", "batch1", "-o", "results", "-l", "logs", "c.inp"]
        self.assertEqual(self.run_cue(argv)[0], 0)
        with mock.patch.object(cue.time, "strftime", return_value=LATER_STAMP):
            status, out, err = self.run_cue(["-f", f"logs/batch1-{JOB_ID}.cue"])
        self.assertEqual((status, err), (0, ""))
        rendered = Path(f"logs/batch1-{LATER_STAMP}.sbatch").read_text()
        self.assert_golden("orca-flags", rendered.replace(LATER_STAMP, STAMP))

    def test_record_rejects_template_or_inputs(self) -> None:
        status, out, err = self.run_cue(["orca", "-f", "x.cue", "a.inp"])
        self.assertEqual(status, 1)
        self.assertIn("-f takes the template", err)

    def test_skip_done_drops_finished_inputs(self) -> None:
        Path("out").mkdir()
        Path("out/a.out").write_text("done")
        status, out, err = self.run_cue(["orca", "--skip-done", "a.inp", "b.inp"])
        self.assertEqual(status, 0)
        self.assertIn("skipping 1 done inputs", err)
        self.assertEqual(Path(f"log/orca-{STAMP}.manifest").read_text(), "b.inp\n")
        self.assertIn("skip_done=1", Path(f"log/orca-{JOB_ID}.cue").read_text())

    def test_skip_done_with_nothing_left_fails(self) -> None:
        Path("out").mkdir()
        Path("out/a.out").write_text("done")
        status, out, err = self.run_cue(["orca", "--skip-done", "a.inp"])
        self.assertEqual(status, 1)
        self.assertIn("every input is done", err)
        self.assertFalse(Path("log").exists())

    def test_dry_run_prints_script_and_writes_nothing(self) -> None:
        status, out, err = self.run_cue(["orca", "--dry-run", "a.inp"])
        self.assertEqual(status, 0)
        self.assertIn("#SBATCH --array=0-0%4\n", out)
        self.assertIn("sbatch: Job 999", err)
        self.assertEqual(self.sbatch_args(), ["--test-only"])
        self.assertFalse(Path("log").exists())
        self.assertFalse(Path("out").exists())

    def test_old_outputs_are_backed_up(self) -> None:
        Path("out").mkdir()
        Path("out/a.out").write_text("old")
        Path("out/a.gbw").write_text("old")
        Path("out/b.out").write_text("keep")
        status, out, err = self.run_cue(["orca", "a.inp"])
        self.assertEqual(status, 0)
        self.assertIn("moved 2 old output files", err)
        self.assertEqual(sorted(p.name for p in Path("out").glob("*.*")), ["b.out"])
        backup = Path("out/backup") / STAMP
        self.assertEqual(sorted(p.name for p in backup.iterdir()), ["a.gbw", "a.out"])

    def test_failed_sbatch_restores_outputs_and_exits_2(self) -> None:
        Path("out").mkdir()
        Path("out/a.out").write_text("old")
        os.environ["FAKE_SBATCH_FAIL"] = "1"
        status, out, err = self.run_cue(["orca", "a.inp"])
        self.assertEqual(status, 2)
        self.assertIn("invalid partition", err)
        self.assertEqual(Path("out/a.out").read_text(), "old")
        self.assertFalse(list(Path("log").glob("*.cue")))

    def test_missing_placeholder_is_a_user_error(self) -> None:
        status, out, err = self.run_cue(["run", "w1.sh"])
        self.assertEqual(status, 1)
        self.assertIn("no value for gpu, ntasks", err)
        self.assertFalse(Path("log").exists())

    def test_engine_values_cannot_be_set(self) -> None:
        status, out, err = self.run_cue(["orca", "--set", "last=9", "a.inp"])
        self.assertEqual(
            (status, err), (1, "cue: --set last is computed by cue and cannot be set\n")
        )

    def test_usage_errors_exit_1(self) -> None:
        for argv in ([], ["orca"], ["orca", "-M", "list.txt", "a.inp"], ["--bogus"]):
            with self.subTest(argv=argv):
                self.assertEqual(self.run_cue(argv)[0], 1)

    def test_wrong_extension_is_rejected(self) -> None:
        status, out, err = self.run_cue(["orca", "w1.sh"])
        self.assertEqual((status, err), (1, "cue: w1.sh does not end with .inp\n"))

    def test_list_show_and_init(self) -> None:
        status, out, err = self.run_cue(["list"])
        self.assertEqual(status, 0)
        self.assertEqual(
            [line.split()[0] for line in out.splitlines()], ["orca", "run"]
        )
        status, out, err = self.run_cue(["show", "orca"])
        self.assertEqual(out, Path("home/templates/orca.sbatch").read_text())
        status, out, err = self.run_cue(["init", "orca"])
        self.assertEqual((status, out), (0, "xdg/cue/templates/orca.sbatch\n"))
        self.assertEqual(self.run_cue(["init", "orca"])[0], 1)
        status, out, err = self.run_cue(["list"])
        self.assertIn("orca             xdg/cue/templates", out)


if __name__ == "__main__":
    unittest.main()
