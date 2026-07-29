"""Tests for cue: golden dry-run scripts and unit behavior."""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

TESTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS_DIR.parent))

# cue is a single file, not an installed package, so the path insert
# above must run before this import.
import cue  # noqa: E402

CONFIG_DIR = TESTS_DIR / "config"
EXPECTED_DIR = TESTS_DIR / "expected"

# name, argv, input files to create. shared with update-goldens.py.
GOLDEN_CASES: list[tuple[str, list[str], list[str]]] = [
    (
        "orca-single-default",
        ["orca", "h2o.inp", "--dry-run"],
        ["h2o.inp"],
    ),
    (
        "orca-single-flags",
        [
            "orca",
            "h2o.inp",
            "-c",
            "8",
            "-m",
            "16",
            "-t",
            "1-00:00:00",
            "--account",
            "mylab",
            "--mail-type",
            "END,FAIL",
            "--mail-user",
            "user@example.com",
            "--dependency",
            "afterok:42",
            "--gpu",
            "1",
            "--dry-run",
        ],
        ["h2o.inp"],
    ),
    (
        "orca-array-throttle",
        ["orca", "a.inp", "b.inp", "c.inp", "-T", "2", "--dry-run"],
        ["a.inp", "b.inp", "c.inp"],
    ),
    (
        "orca-no-archive",
        ["orca", "h2o.inp", "--no-archive", "--dry-run"],
        ["h2o.inp"],
    ),
    (
        "orca-variant-exclude",
        ["orca", "h2o.inp", "--variant", "old", "--dry-run"],
        ["h2o.inp"],
    ),
    (
        "gaussian-single-default",
        ["gaussian", "h2o.com", "--dry-run"],
        ["h2o.com"],
    ),
    (
        "gpaw-single-default",
        ["gpaw", "relax.py", "--dry-run"],
        ["relax.py"],
    ),
    (
        "gpaw-array-default",
        ["gpaw", "a.py", "b.py", "--dry-run"],
        ["a.py", "b.py"],
    ),
    (
        "run-single-default",
        ["run", "hello.sh", "--dry-run"],
        ["hello.sh"],
    ),
    (
        "run-launcher",
        ["run", "hello.py", "--launcher", "python3", "--dry-run"],
        ["hello.py"],
    ),
    (
        "dalton-pair-single",
        ["dalton", "hf.dal", "water.mol", "--dry-run"],
        ["hf.dal", "water.mol"],
    ),
    (
        "dalton-pair-array",
        ["dalton", "dft.dal", "a.mol", "b.mol", "c.mol", "-m", "32", "--dry-run"],
        ["dft.dal", "a.mol", "b.mol", "c.mol"],
    ),
    (
        "dirac-pair-single",
        ["dirac", "sp_hf.inp", "hgh2.mol", "-c", "4", "-m", "20", "--dry-run"],
        ["sp_hf.inp", "hgh2.mol"],
    ),
    (
        "cfour-single-default",
        ["cfour", "ccsd.inp", "-c", "2", "--dry-run"],
        ["ccsd.inp"],
    ),
    (
        "python-single-default",
        ["python", "analysis.py", "-c", "4", "--dry-run"],
        ["analysis.py"],
    ),
    (
        "fdmnes-single-default",
        ["fdmnes", "input/CeS8_inp.txt", "--dry-run"],
        ["input/CeS8_inp.txt"],
    ),
    (
        "xtb-single-default",
        ["xtb", "mol.xyz", "-c", "4", "--dry-run"],
        ["mol.xyz"],
    ),
    (
        "turbomole-parent-single",
        ["turbomole", "benzene/control", "--dry-run"],
        ["benzene/control"],
    ),
    (
        "turbomole-parent-array",
        ["turbomole", "benzene/control", "naphthalene/control", "--dry-run"],
        ["benzene/control", "naphthalene/control"],
    ),
    (
        "xtb-mem-per-cpu",
        ["xtb", "mol.xyz", "-c", "4", "--mem-per-cpu", "3", "--dry-run"],
        ["mol.xyz"],
    ),
    (
        "xtb-args",
        ["xtb", "mol.xyz", "--args", "--opt --gfn 2 --chrg 1", "--dry-run"],
        ["mol.xyz"],
    ),
]


def run_cue(argv: list[str]) -> tuple[int, str, str]:
    """Run cue.main, returning exit code, stdout, and stderr."""
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        code = cue.main(["cue", *argv])
    return code, stdout.getvalue(), stderr.getvalue()


class TempCwdTestCase(unittest.TestCase):
    """Run each test in a fresh temp directory with the fixture configs."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._old_cwd = os.getcwd()
        os.chdir(self._tmp.name)
        self.addCleanup(os.chdir, self._old_cwd)
        patcher = mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(CONFIG_DIR)})
        patcher.start()
        self.addCleanup(patcher.stop)

    def touch(self, *names: str) -> None:
        for name in names:
            Path(name).parent.mkdir(parents=True, exist_ok=True)
            Path(name).write_text("")


class GoldenTests(TempCwdTestCase):
    def test_goldens(self) -> None:
        for name, argv, files in GOLDEN_CASES:
            with self.subTest(golden=name):
                self.touch(*files)
                code, stdout, stderr = run_cue(argv)
                self.assertEqual(code, 0, stderr)
                expected = (EXPECTED_DIR / f"{name}.slurm").read_text()
                self.assertEqual(stdout, expected)


class ShippedConfigTests(unittest.TestCase):
    def test_all_shipped_configs_parse_and_render(self) -> None:
        tasks_dir = TESTS_DIR.parent / "configs" / "tasks"
        for path in sorted(tasks_dir.glob("*.toml")):
            with self.subTest(config=path.name):
                task = cue.parse_task_config(path, path.stem)
                self.assertTrue(task.command)
                values = {key: "x" for key in cue.ENGINE_PLACEHOLDERS}
                values.update(task.paths)
                # unknown placeholders in shipped configs must fail here,
                # not on a user's first submission.
                cue.substitute(task.setup, values, path.name)
                cue.substitute(task.command, values, path.name)


class ValidationTests(TempCwdTestCase):
    def test_unknown_task(self) -> None:
        code, _, stderr = run_cue(["orcaa", "h2o.inp"])
        self.assertEqual(code, 1)
        self.assertIn('unknown task "orcaa"', stderr)
        self.assertIn("orca", stderr)

    def test_missing_input(self) -> None:
        code, _, stderr = run_cue(["orca", "h2o.inp", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('"h2o.inp" not found', stderr)

    def test_wrong_extension(self) -> None:
        self.touch("h2o.xyz")
        code, _, stderr = run_cue(["orca", "h2o.xyz", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn(".inp", stderr)

    def test_duplicate_input(self) -> None:
        self.touch("h2o.inp")
        code, _, stderr = run_cue(["orca", "h2o.inp", "h2o.inp", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("more than once", stderr)

    def test_invalid_time(self) -> None:
        self.touch("h2o.inp")
        code, _, stderr = run_cue(["orca", "h2o.inp", "-t", "tomorrow", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("invalid --time", stderr)

    def test_time_formats(self) -> None:
        valid = ["30", "30:00", "12:00:00", "1-12", "1-12:00", "1-12:00:00"]
        for value in valid:
            self.assertIsNotNone(cue.TIME_LIMIT_RE.fullmatch(value), value)
        invalid = ["", "1:2:3", "one", "1-123", "12:00:00:00"]
        for value in invalid:
            self.assertIsNone(cue.TIME_LIMIT_RE.fullmatch(value), value)

    def test_invalid_characters(self) -> None:
        code, _, stderr = run_cue(["orca", "h2$o.inp", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("unsupported characters", stderr)

    def test_duplicate_stem(self) -> None:
        Path("a").mkdir()
        Path("b").mkdir()
        self.touch("a/x.inp", "b/x.inp")
        code, _, stderr = run_cue(["orca", "a/x.inp", "b/x.inp", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("both write results", stderr)

    def test_max_array_size(self) -> None:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "cue.toml").write_text("[defaults]\nmax_array_size = 2\n")
        (config / "tasks" / "run.toml").write_text(
            "[execution]\ncommand = 'bash \"{input}\"'\n"
        )
        self.touch("a.sh", "b.sh", "c.sh")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["run", "a.sh", "b.sh", "c.sh", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("max_array_size", stderr)

    def test_max_cpus(self) -> None:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "cue.toml").write_text("[defaults]\nmax_cpus = 4\n")
        (config / "tasks" / "run.toml").write_text(
            "[execution]\ncommand = 'bash \"{input}\"'\n"
        )
        self.touch("a.sh")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["run", "a.sh", "-c", "8", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("max_cpus", stderr)


class PairedInputTests(TempCwdTestCase):
    def test_alternating_pairs(self) -> None:
        self.touch("a.inp", "a.mol", "b.inp", "b.mol")
        code, stdout, stderr = run_cue(
            ["dirac", "a.inp", "a.mol", "b.inp", "b.mol", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("--array=1-2%5", stdout)
        self.assertIn(".a-a.manifest", stdout)

    def test_secondary_before_primary(self) -> None:
        self.touch("water.mol", "hf.dal")
        code, _, stderr = run_cue(["dalton", "water.mol", "hf.dal", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("comes before any .dal file", stderr)

    def test_primary_without_secondary(self) -> None:
        self.touch("hf.dal")
        code, _, stderr = run_cue(["dalton", "hf.dal", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("has no .mol file", stderr)

    def test_trailing_unpaired_primary(self) -> None:
        self.touch("a.dal", "a.mol", "b.dal")
        code, _, stderr = run_cue(["dalton", "a.dal", "a.mol", "b.dal", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('"b.dal" has no .mol file', stderr)

    def test_duplicate_pair(self) -> None:
        self.touch("a.dal", "a.mol")
        code, _, stderr = run_cue(["dalton", "a.dal", "a.mol", "a.mol", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("more than once", stderr)

    def test_wrong_extension_in_pairs(self) -> None:
        self.touch("a.dal", "a.xyz")
        code, _, stderr = run_cue(["dalton", "a.dal", "a.xyz", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("secondary extensions", stderr)

    def test_paired_manifest_written(self) -> None:
        self.touch("a.dal", "a.mol", "b.mol")
        bin_dir = Path("fakebin")
        bin_dir.mkdir()
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(
            "#!/bin/bash\ncat > /dev/null\necho 'Submitted batch job 9'\n"
        )
        sbatch.chmod(0o755)
        with mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        ):
            code, _, stderr = run_cue(["dalton", "a.dal", "a.mol", "b.mol"])
        self.assertEqual(code, 0, stderr)
        self.assertEqual(
            Path(".a-a.manifest").read_text(), "a.dal\ta.mol\na.dal\tb.mol\n"
        )


class InjectTests(TempCwdTestCase):
    def submit_dry(self, argv: list[str]) -> tuple[int, str, str]:
        return run_cue([*argv, "--inject-resources", "--dry-run"])

    def test_orca_replaces_existing_directives(self) -> None:
        Path("h2o.inp").write_text("%pal nprocs 2 end\n%maxcore 1000\n! b3lyp\n")
        bin_dir = Path("fakebin")
        bin_dir.mkdir()
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(
            "#!/bin/bash\ncat > /dev/null\necho 'Submitted batch job 1'\n"
        )
        sbatch.chmod(0o755)
        with mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        ):
            code, _, stderr = run_cue(
                ["orca", "h2o.inp", "-c", "4", "-m", "16", "--inject-resources"]
            )
        self.assertEqual(code, 0, stderr)
        staged = Path(".cue-staged/h2o.inp").read_text()
        self.assertIn("%pal nprocs 4 end", staged)
        # 16 GB * 1024 * 0.75 / 4 cores
        self.assertIn("%maxcore 3072", staged)
        self.assertNotIn("%maxcore 1000", staged)
        # the original is untouched.
        self.assertIn("%maxcore 1000", Path("h2o.inp").read_text())

    def test_orca_inserts_missing_directives(self) -> None:
        Path("h2o.inp").write_text("! b3lyp def2-svp\n")
        code, stdout, stderr = self.submit_dry(["orca", "h2o.inp", "-c", "2"])
        self.assertEqual(code, 0, stderr)
        self.assertIn(".cue-staged/h2o.inp", stdout)
        self.assertFalse(Path(".cue-staged").exists())

    def test_multiline_pal_block_replaced(self) -> None:
        Path("h2o.inp").write_text("%pal\n  nprocs 8\nend\n! hf\n")
        values = {"cpus": "4", "inject_memory_mb_per_cpu": "1536"}
        task = cue.parse_task_config(CONFIG_DIR / "tasks" / "orca.toml", "orca")
        result = cue.apply_inject_rules(
            "%pal\n  nprocs 8\nend\n! hf\n", task, values, "h2o.inp"
        )
        self.assertIn("%pal nprocs 4 end", result)
        self.assertNotIn("nprocs 8", result)

    def test_gaussian_spelling_rewritten(self) -> None:
        Path("h2o.com").write_text("%nprocs=2\n%mem=1GB\n#p b3lyp\n")
        code, _, stderr = self.submit_dry(
            ["gaussian", "h2o.com", "-c", "8", "-m", "16"]
        )
        self.assertEqual(code, 0, stderr)
        task = cue.parse_task_config(CONFIG_DIR / "tasks" / "gaussian.toml", "gaussian")
        values = {"cpus": "8", "inject_memory_mb": "13926"}
        result = cue.apply_inject_rules(
            Path("h2o.com").read_text(), task, values, "h2o.com"
        )
        self.assertIn("%nprocshared=8", result)
        self.assertIn("%mem=13926MB", result)
        self.assertNotIn("%nprocs=2", result)

    def test_ambiguous_directives_abort(self) -> None:
        Path("h2o.com").write_text("%mem=1GB\n%mem=2GB\n#p hf\n")
        code, _, stderr = self.submit_dry(["gaussian", "h2o.com"])
        self.assertEqual(code, 1)
        self.assertIn("2 lines matching", stderr)
        self.assertIn("lines 1, 2", stderr)

    def test_flag_without_rules(self) -> None:
        self.touch("relax.py")
        code, _, stderr = self.submit_dry(["gpaw", "relax.py"])
        self.assertEqual(code, 1)
        self.assertIn("[inject] rules", stderr)


class JobFileTests(TempCwdTestCase):
    def _install_fake_sbatch(self) -> None:
        bin_dir = Path("fakebin")
        bin_dir.mkdir(exist_ok=True)
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(
            "#!/bin/bash\ncat > /dev/null\necho 'Submitted batch job 321'\n"
        )
        sbatch.chmod(0o755)
        patcher = mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_file_settings_applied(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text(
            'cpus = 8\nmemory = 16\nargs = "--opt"\ninput = ["mol.xyz"]\n'
        )
        code, stdout, stderr = run_cue(["xtb", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--cpus-per-task=8", stdout)
        self.assertIn("--mem=16gb", stdout)
        self.assertIn('"$input" --opt >', stdout)

    def test_cli_overrides_file(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text('cpus = 8\ninput = ["mol.xyz"]\n')
        code, stdout, stderr = run_cue(["xtb", "-f", "job.cue", "-c", "2", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--cpus-per-task=2", stdout)

    def test_file_inputs_relative_to_file(self) -> None:
        self.touch("runs/mol.xyz")
        Path("runs/job.cue").write_text('input = ["mol.xyz"]\n')
        code, stdout, stderr = run_cue(["xtb", "-f", "runs/job.cue", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn('input_path="runs/mol.xyz"', stdout)

    def test_task_mismatch(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text('task = "orca"\ninput = ["mol.xyz"]\n')
        code, _, stderr = run_cue(["xtb", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('job file is for task "orca"', stderr)

    def test_unknown_key(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text("cores = 8\n")
        code, _, stderr = run_cue(["xtb", "mol.xyz", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('"cores"', stderr)

    def test_no_inputs_anywhere(self) -> None:
        Path("job.cue").write_text("cpus = 2\n")
        code, _, stderr = run_cue(["xtb", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("no inputs given", stderr)

    def test_auto_record_written_and_rerunnable(self) -> None:
        self._install_fake_sbatch()
        self.touch("mol.xyz")
        code, _, stderr = run_cue(["xtb", "mol.xyz", "-c", "4"])
        self.assertEqual(code, 0, stderr)
        records = list(Path("out/.rec").glob("*-321.cue"))
        self.assertEqual(len(records), 1)
        content = records[0].read_text()
        self.assertNotIn("#", content)
        self.assertIn('task = "xtb"', content)
        self.assertIn("cpus = 4", content)
        code, stdout, stderr = run_cue(["xtb", "-f", str(records[0]), "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--cpus-per-task=4", stdout)

    def test_auto_record_prunes_oldest(self) -> None:
        self._install_fake_sbatch()
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "cue.toml").write_text("[defaults]\nrecord_limit = 2\n")
        (config / "tasks" / "run.toml").write_text(
            "[execution]\ncommand = 'bash \"{input}\"'\n"
        )
        record_dir = Path("out/.rec")
        record_dir.mkdir(parents=True)
        (record_dir / "2000-01-01-00-00-00-1.cue").write_text("")
        (record_dir / "2000-01-02-00-00-00-2.cue").write_text("")
        self.touch("a.sh")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["run", "a.sh"])
        self.assertEqual(code, 0, stderr)
        names = sorted(p.name for p in record_dir.glob("*.cue"))
        self.assertEqual(len(names), 2)
        self.assertNotIn("2000-01-01-00-00-00-1.cue", names)

    def test_visible_record_adds_to_auto(self) -> None:
        self._install_fake_sbatch()
        self.touch("mol.xyz")
        code, stdout, stderr = run_cue(["xtb", "mol.xyz", "--record"])
        self.assertEqual(code, 0, stderr)
        self.assertEqual(len(list(Path("out/.rec").glob("*.cue"))), 1)
        visible = list(Path(".").glob("cue-xtb-mol-*.cue"))
        self.assertEqual(len(visible), 1)
        content = visible[0].read_text()
        self.assertIn("# recorded by cue", content)
        self.assertIn("# job id: 321", content)

    def test_record_to_named_file(self) -> None:
        self._install_fake_sbatch()
        self.touch("mol.xyz")
        code, stdout, stderr = run_cue(["xtb", "mol.xyz", "--record", "myrun.cue"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("recorded: myrun.cue", stdout)
        self.assertIn('task = "xtb"', Path("myrun.cue").read_text())


class StemParentTests(TempCwdTestCase):
    def test_stems_from_directories(self) -> None:
        self.touch("benzene/control", "naphthalene/control")
        code, stdout, stderr = run_cue(
            ["turbomole", "benzene/control", "naphthalene/control", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("--job-name=benzene", stdout)
        self.assertIn('stem="$(basename "$(dirname "$input_path")")"', stdout)

    def test_bare_input_rejected(self) -> None:
        self.touch("control")
        code, _, stderr = run_cue(["turbomole", "control", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("has no calculation directory", stderr)

    def test_same_directory_collides(self) -> None:
        self.touch("benzene/control")
        code, _, stderr = run_cue(
            ["turbomole", "benzene/control", "benzene/control", "--dry-run"]
        )
        self.assertEqual(code, 1)
        self.assertIn("more than once", stderr)

    def test_invalid_stem_value(self) -> None:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "tasks" / "bad.toml").write_text(
            '[task]\nstem = "folder"\n[execution]\ncommand = "x"\n'
        )
        self.touch("a/control")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["bad", "a/control", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('"name" or "parent"', stderr)

    def test_parent_rejects_inject_rules(self) -> None:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "tasks" / "bad.toml").write_text(
            '[task]\nstem = "parent"\n[execution]\ncommand = "x"\n'
            "[inject]\nrules = ["
            "{ match = '^%mem', write = \"%mem {inject_memory_mb}\" }]\n"
        )
        self.touch("a/control")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["bad", "a/control", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("[inject]", stderr)
        self.assertIn("collide", stderr)


class MemPerCpuTests(TempCwdTestCase):
    def test_mutually_exclusive_with_memory(self) -> None:
        self.touch("mol.xyz")
        with self.assertRaises(SystemExit):
            run_cue(["xtb", "mol.xyz", "-m", "8", "--mem-per-cpu", "2", "--dry-run"])

    def test_placeholder_uses_total(self) -> None:
        self.touch("hf.dal", "w.mol")
        code, stdout, stderr = run_cue(
            ["dalton", "hf.dal", "w.mol", "-c", "4", "--mem-per-cpu", "3", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("#SBATCH --mem-per-cpu=3gb", stdout)
        self.assertNotIn("#SBATCH --mem=", stdout)
        # dalton -gb uses {memory_gb} = per_cpu * cpus.
        self.assertIn("-gb 12", stdout)

    def test_job_file_conflict(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text('memory = 8\nmem_per_cpu = 2\ninput = ["mol.xyz"]\n')
        code, _, stderr = run_cue(["xtb", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("both memory and mem_per_cpu", stderr)


class AfterParsableTests(TempCwdTestCase):
    def _fake_sbatch(self) -> None:
        bin_dir = Path("fakebin")
        bin_dir.mkdir(exist_ok=True)
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(
            "#!/bin/bash\ncat > /dev/null\necho 'Submitted batch job 99'\n"
        )
        sbatch.chmod(0o755)
        patcher = mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_after_translates(self) -> None:
        self.touch("mol.xyz")
        code, stdout, stderr = run_cue(
            ["xtb", "mol.xyz", "--after", "11,22", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("#SBATCH --dependency=afterok:11:22", stdout)

    def test_after_conflicts_with_dependency(self) -> None:
        self.touch("mol.xyz")
        code, _, stderr = run_cue(
            [
                "xtb",
                "mol.xyz",
                "--after",
                "11",
                "--dependency",
                "afterok:2",
                "--dry-run",
            ]
        )
        self.assertEqual(code, 1)
        self.assertIn("not both", stderr)

    def test_after_rejects_names(self) -> None:
        self.touch("mol.xyz")
        code, _, stderr = run_cue(["xtb", "mol.xyz", "--after", "myjob", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("numeric job ids", stderr)

    def test_parsable_prints_only_id(self) -> None:
        self._fake_sbatch()
        self.touch("mol.xyz")
        Path("out").mkdir()
        Path("out/mol.out").write_text("old")
        code, stdout, stderr = run_cue(["xtb", "mol.xyz", "--parsable"])
        self.assertEqual(code, 0, stderr)
        self.assertEqual(stdout.strip(), "99")
        self.assertIn("submitted job 99", stderr)
        self.assertIn("backup:", stderr)


class OutdirLogdirTests(TempCwdTestCase):
    def _fake_sbatch(self) -> None:
        bin_dir = Path("fakebin")
        bin_dir.mkdir(exist_ok=True)
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(
            "#!/bin/bash\ncat > /dev/null\necho 'Submitted batch job 321'\n"
        )
        sbatch.chmod(0o755)
        patcher = mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_flags_change_directories(self) -> None:
        self.touch("mol.xyz")
        code, stdout, stderr = run_cue(
            ["xtb", "mol.xyz", "--outdir", "results", "--logdir", "logs", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn("#SBATCH --output=logs/%x.log", stdout)
        self.assertIn('mkdir -p "results" "logs"', stdout)
        self.assertIn('"$SLURM_SUBMIT_DIR/results/$stem.out"', stdout)
        self.assertIn('tar -cJf "results/$stem.tar.xz"', stdout)

    def test_flag_aliases(self) -> None:
        self.touch("mol.xyz")
        for argv in (
            ["xtb", "mol.xyz", "-o", "r1", "-l", "l1", "--dry-run"],
            ["xtb", "mol.xyz", "--out", "r1", "--log", "l1", "--dry-run"],
        ):
            code, stdout, stderr = run_cue(argv)
            self.assertEqual(code, 0, stderr)
            self.assertIn("#SBATCH --output=l1/%x.log", stdout)
            self.assertIn('mkdir -p "r1" "l1"', stdout)

    def test_config_precedence(self) -> None:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True)
        (config / "cue.toml").write_text(
            '[defaults]\noutdir = "siteout"\nlogdir = "sitelog"\n'
        )
        (config / "tasks" / "mytask.toml").write_text(
            '[execution]\ncommand = \'bash "{input}"\'\noutdir = "taskout"\n'
        )
        self.touch("run.sh")
        env = {cue.CONFIG_PATH_ENV: str(config)}
        with mock.patch.dict(os.environ, env):
            code, stdout, stderr = run_cue(["mytask", "run.sh", "--dry-run"])
            self.assertEqual(code, 0, stderr)
            # task config beats site for outdir, site fills logdir.
            self.assertIn('mkdir -p "taskout" "sitelog"', stdout)
            code, stdout, stderr = run_cue(
                ["mytask", "run.sh", "--outdir", "cliout", "--dry-run"]
            )
            self.assertEqual(code, 0, stderr)
            self.assertIn('mkdir -p "cliout" "sitelog"', stdout)

    def test_invalid_directory_rejected(self) -> None:
        self.touch("mol.xyz")
        code, _, stderr = run_cue(
            ["xtb", "mol.xyz", "--outdir", "bad dir", "--dry-run"]
        )
        self.assertEqual(code, 1)
        self.assertIn("unsupported characters", stderr)

    def test_job_file_outdir(self) -> None:
        self.touch("mol.xyz")
        Path("job.cue").write_text('outdir = "jf"\ninput = ["mol.xyz"]\n')
        code, stdout, stderr = run_cue(["xtb", "-f", "job.cue", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn('mkdir -p "jf" "log"', stdout)

    def test_records_follow_outdir(self) -> None:
        self._fake_sbatch()
        self.touch("mol.xyz")
        code, _, stderr = run_cue(["xtb", "mol.xyz", "--outdir", "results"])
        self.assertEqual(code, 0, stderr)
        records = list(Path("results/.rec").glob("*-321.cue"))
        self.assertEqual(len(records), 1)
        content = records[0].read_text()
        self.assertIn("outdir = 'results'", content)
        self.assertIn("logdir = 'log'", content)
        self.assertFalse(Path("out/.rec").exists())


class ManifestFlagTests(TempCwdTestCase):
    def test_manifest_inputs(self) -> None:
        self.touch("runs/a.xyz", "runs/b.xyz")
        Path("runs/list.txt").write_text("# comment\na.xyz\n\nb.xyz\n")
        code, stdout, stderr = run_cue(["xtb", "-M", "runs/list.txt", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--array=1-2%5", stdout)

    def test_manifest_missing(self) -> None:
        code, _, stderr = run_cue(["xtb", "-M", "nope.txt", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("manifest nope.txt not found", stderr)

    def test_manifest_empty(self) -> None:
        Path("list.txt").write_text("# only comments\n")
        code, _, stderr = run_cue(["xtb", "-M", "list.txt", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("lists no input files", stderr)

    def test_positionals_and_manifest_concatenate(self) -> None:
        self.touch("a.xyz", "b.xyz")
        Path("list.txt").write_text("b.xyz\n")
        code, stdout, stderr = run_cue(["xtb", "a.xyz", "-M", "list.txt", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--array=1-2%5", stdout)

    def test_manifest_key_in_job_file(self) -> None:
        self.touch("runs/a.xyz")
        Path("runs/list.txt").write_text("a.xyz\n")
        Path("runs/job.cue").write_text('manifest = "list.txt"\ncpus = 3\n')
        code, stdout, stderr = run_cue(["xtb", "-f", "runs/job.cue", "--dry-run"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("--cpus-per-task=3", stdout)
        self.assertIn('input_path="runs/a.xyz"', stdout)


class TemplateTests(TempCwdTestCase):
    def test_stdout(self) -> None:
        code, stdout, _ = run_cue(["template"])
        self.assertEqual(code, 0)
        self.assertIn("# cpus = 8", stdout)
        self.assertIn("# input = [", stdout)

    def test_write_and_refuse_overwrite(self) -> None:
        code, _, stderr = run_cue(["template", "job.cue"])
        self.assertEqual(code, 0, stderr)
        self.assertTrue(Path("job.cue").is_file())
        code, _, stderr = run_cue(["template", "job.cue"])
        self.assertEqual(code, 1)
        self.assertIn("already exists", stderr)

    def test_template_is_valid_toml(self) -> None:
        import tomllib

        self.assertEqual(tomllib.loads(cue.JOB_TEMPLATE), {})


class ArgsFlagTests(TempCwdTestCase):
    def test_args_substituted(self) -> None:
        self.touch("mol.xyz")
        code, stdout, stderr = run_cue(
            ["xtb", "mol.xyz", "--args", "--opt --chrg 1", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn('"$input" --opt --chrg 1 >', stdout)

    def test_args_rejected_without_placeholder(self) -> None:
        self.touch("relax.py")
        code, _, stderr = run_cue(
            ["gpaw", "relax.py", "--args=--opt --tight", "--dry-run"]
        )
        self.assertEqual(code, 1)
        self.assertIn("does not take --args", stderr)


class SetFlagTests(TempCwdTestCase):
    def test_set_overrides_path(self) -> None:
        self.touch("ccsd.inp")
        code, stdout, stderr = run_cue(
            ["cfour", "ccsd.inp", "--set", "genbas=/custom/GENBAS", "--dry-run"]
        )
        self.assertEqual(code, 0, stderr)
        self.assertIn('cp "/custom/GENBAS" GENBAS', stdout)

    def test_set_unknown_key(self) -> None:
        self.touch("ccsd.inp")
        code, _, stderr = run_cue(
            ["cfour", "ccsd.inp", "--set", "genbass=/x", "--dry-run"]
        )
        self.assertEqual(code, 1)
        self.assertIn('"genbass" is not in [paths]', stderr)
        self.assertIn("genbas", stderr)

    def test_set_bad_format(self) -> None:
        self.touch("ccsd.inp")
        code, _, stderr = run_cue(["cfour", "ccsd.inp", "--set", "genbas", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("use --set key=value", stderr)


class ConfigTests(TempCwdTestCase):
    def write_task(self, body: str) -> Path:
        config = Path("localconfig")
        (config / "tasks").mkdir(parents=True, exist_ok=True)
        path = config / "tasks" / "bad.toml"
        path.write_text(body)
        return config

    def run_bad(self, body: str) -> str:
        config = self.write_task(body)
        self.touch("a.sh")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["bad", "a.sh", "--dry-run"])
        self.assertEqual(code, 1)
        return stderr

    def test_missing_command(self) -> None:
        stderr = self.run_bad("[execution]\nscratch = true\n")
        self.assertIn("[execution].command", stderr)

    def test_archive_requires_scratch(self) -> None:
        stderr = self.run_bad("[execution]\ncommand = 'x'\narchive = true\n")
        self.assertIn("archive", stderr)
        self.assertIn("scratch", stderr)

    def test_unknown_key(self) -> None:
        stderr = self.run_bad("[execution]\ncommand = 'x'\ntypo_key = 1\n")
        self.assertIn("typo_key", stderr)
        self.assertIn("allowed keys", stderr)

    def test_paths_shadow_engine_placeholder(self) -> None:
        stderr = self.run_bad("[execution]\ncommand = 'x'\n[paths]\ninput = '/x'\n")
        self.assertIn("shadows a built-in placeholder", stderr)

    def test_unknown_placeholder(self) -> None:
        stderr = self.run_bad("[execution]\ncommand = 'run {typo}'\n")
        self.assertIn('unknown placeholder "{typo}"', stderr)

    def test_retrieve_entry_validated(self) -> None:
        stderr = self.run_bad(
            "[execution]\ncommand = 'x'\nscratch = true\nretrieve = ['g bw']\n"
        )
        self.assertIn("retrieve entry", stderr)

    def test_site_layering_first_dir_wins(self) -> None:
        high = Path("high")
        low = Path("low")
        high.mkdir()
        low.mkdir()
        (high / "cue.toml").write_text("[defaults]\ncpus = 4\n")
        (low / "cue.toml").write_text("[defaults]\ncpus = 2\nmemory_gb = 8\n")
        site = cue.load_site_defaults([high, low])
        self.assertEqual(site.cpus, 4)
        self.assertEqual(site.memory_gb, 8)

    def test_discover_first_dir_wins(self) -> None:
        high = Path("high/tasks")
        low = Path("low/tasks")
        high.mkdir(parents=True)
        low.mkdir(parents=True)
        (high / "orca.toml").write_text("")
        (low / "orca.toml").write_text("")
        (low / "xtb.toml").write_text("")
        found = cue.discover_tasks([Path("high"), Path("low")])
        self.assertEqual(found["orca"], high / "orca.toml")
        self.assertEqual(found["xtb"], low / "xtb.toml")


class BackupTests(TempCwdTestCase):
    def test_backup_counts_up(self) -> None:
        output = Path("output")
        output.mkdir()
        for _ in range(3):
            (output / "h2o.out").write_text("data")
            with contextlib.redirect_stdout(io.StringIO()):
                cue.backup_existing_outputs(output, ["h2o"])
        backups = sorted(p.name for p in (output / "backup").iterdir())
        self.assertEqual(
            backups,
            ["h2o.out.bck01", "h2o.out.bck02", "h2o.out.bck03"],
        )

    def test_backup_full_fails(self) -> None:
        backup_dir = Path("output/backup")
        backup_dir.mkdir(parents=True)
        for index in range(1, cue.MAX_BACKUP_INDEX + 1):
            (backup_dir / f"h2o.out.bck{index:02d}").write_text("")
        with self.assertRaises(cue.CueError):
            cue._next_backup_path(backup_dir, "h2o.out")


class ManifestTests(TempCwdTestCase):
    def test_manifest_content(self) -> None:
        path = Path(".jobs.manifest")
        cue.write_manifest(path, ["a.inp", "b.inp"])
        self.assertEqual(path.read_text(), "a.inp\nb.inp\n")
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)


class SearchPathTests(unittest.TestCase):
    def test_default_dirs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"HOME": tmp}):
                os.environ.pop(cue.CONFIG_PATH_ENV, None)
                dirs = cue.resolve_search_path()
        self.assertEqual(dirs, (Path(tmp) / ".config" / "cue", Path(tmp) / "bin"))

    def test_configured_search_path_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_dir = Path(tmp) / ".config" / "cue"
            config_dir.mkdir(parents=True)
            (config_dir / "cue.toml").write_text('search_path = ["/x", "/y"]\n')
            with mock.patch.dict(os.environ, {"HOME": tmp}):
                os.environ.pop(cue.CONFIG_PATH_ENV, None)
                dirs = cue.resolve_search_path()
        self.assertEqual(dirs, (Path("/x"), Path("/y")))

    def test_env_var_wins(self) -> None:
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: "/a:/b"}):
            dirs = cue.resolve_search_path()
        self.assertEqual(dirs, (Path("/a"), Path("/b")))

    def test_init_custom_dir_writes_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"HOME": tmp}):
                os.environ.pop(cue.CONFIG_PATH_ENV, None)
                code, _, stderr = run_cue(["init", "--dir", f"{tmp}/my-configs"])
                self.assertEqual(code, 0, stderr)
                dirs = cue.resolve_search_path()
        self.assertEqual(dirs, (Path(tmp) / "my-configs",))

    def test_flat_toml_in_bin(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            (bin_dir / "orca.toml").write_text("")
            (bin_dir / "cue.toml").write_text("")
            found = cue.discover_tasks([bin_dir])
            self.assertEqual(found, {"orca": bin_dir / "orca.toml"})
            self.assertEqual(
                cue.find_task_config("orca", [bin_dir]),
                bin_dir / "orca.toml",
            )


class InitTests(TempCwdTestCase):
    def _run_in_home(self, argv: list[str]) -> tuple[int, str, str]:
        with mock.patch.dict(os.environ):
            os.environ.pop(cue.CONFIG_PATH_ENV, None)
            os.environ["HOME"] = os.getcwd()
            return run_cue(argv)

    def test_relative_dir_pointer_is_absolute(self) -> None:
        code, _, stderr = self._run_in_home(["init", "--dir", "my-configs"])
        self.assertEqual(code, 0, stderr)
        bootstrap = Path(".config/cue/cue.toml")
        self.assertIn(str(Path.cwd() / "my-configs"), bootstrap.read_text())

    def test_pointer_note_when_bootstrap_exists(self) -> None:
        boot_dir = Path(".config/cue")
        boot_dir.mkdir(parents=True)
        (boot_dir / "cue.toml").write_text('search_path = ["/x"]\n')
        code, stdout, stderr = self._run_in_home(["init", "--dir", "other"])
        self.assertEqual(code, 0, stderr)
        self.assertIn(str(Path.cwd() / "other"), stdout)
        self.assertIn("--force", stdout)
        self.assertEqual((boot_dir / "cue.toml").read_text(), 'search_path = ["/x"]\n')

    def test_force_replaces_pointer(self) -> None:
        boot_dir = Path(".config/cue")
        boot_dir.mkdir(parents=True)
        (boot_dir / "cue.toml").write_text('search_path = ["/x"]\n')
        code, stdout, stderr = self._run_in_home(["init", "--dir", "other", "--force"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("updated:", stdout)
        content = (boot_dir / "cue.toml").read_text()
        self.assertIn(str(Path.cwd() / "other"), content)
        self.assertNotIn('"/x"', content)

    def test_force_refuses_to_drop_defaults(self) -> None:
        boot_dir = Path(".config/cue")
        boot_dir.mkdir(parents=True)
        (boot_dir / "cue.toml").write_text(
            'search_path = ["/x"]\n[defaults]\ncpus = 4\n'
        )
        code, _, stderr = self._run_in_home(["init", "--dir", "other", "--force"])
        self.assertEqual(code, 1)
        self.assertIn("refusing", stderr)
        self.assertIn("cpus = 4", (boot_dir / "cue.toml").read_text())


class ExampleProtectionTests(TempCwdTestCase):
    def test_example_never_listed_or_submitted(self) -> None:
        config = Path("cfg")
        (config / "tasks").mkdir(parents=True)
        (config / "tasks" / "example.toml").write_text("[execution]\ncommand = 'x'\n")
        (config / "example.toml").write_text("[execution]\ncommand = 'x'\n")
        (config / "tasks" / "mytask.toml").write_text(
            "[execution]\ncommand = 'bash \"{input}\"'\n"
        )
        self.touch("a.sh")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            found = cue.discover_tasks([config])
            self.assertEqual(set(found), {"mytask"})
            self.assertIsNone(cue.find_task_config("example", [config]))
            code, _, stderr = run_cue(["example", "a.sh", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn('unknown task "example"', stderr)


class LinkTests(TempCwdTestCase):
    def test_link_creates_symlinks_and_skips_reserved(self) -> None:
        config = Path("cfg")
        (config / "tasks").mkdir(parents=True)
        (config / "tasks" / "orca.toml").write_text("")
        (config / "tasks" / "list.toml").write_text("")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, _, stderr = run_cue(["link", "--dir", "bin"])
        self.assertEqual(code, 0, stderr)
        bin_dir = Path("bin")
        self.assertTrue((bin_dir / "sorca").is_symlink())
        self.assertTrue((bin_dir / "sint").is_symlink())
        self.assertFalse((bin_dir / "slist").exists())
        self.assertEqual((bin_dir / "sorca").resolve(), Path(cue.__file__).resolve())

    def test_list_marks_shadowed_config(self) -> None:
        config = Path("cfg")
        (config / "tasks").mkdir(parents=True)
        (config / "tasks" / "list.toml").write_text("")
        with mock.patch.dict(os.environ, {cue.CONFIG_PATH_ENV: str(config)}):
            code, stdout, _ = run_cue(["list"])
        self.assertEqual(code, 0)
        self.assertIn("shadowed by the built-in command", stdout)


class SubmitTests(TempCwdTestCase):
    def _install_fake_sbatch(self, script: str) -> None:
        bin_dir = Path("fakebin")
        bin_dir.mkdir()
        sbatch = bin_dir / "sbatch"
        sbatch.write_text(script)
        sbatch.chmod(0o755)
        patcher = mock.patch.dict(
            os.environ, {"PATH": f"{bin_dir.resolve()}:{os.environ['PATH']}"}
        )
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_array_submission_end_to_end(self) -> None:
        self._install_fake_sbatch(
            "#!/bin/bash\ncat > submitted.slurm\necho 'Submitted batch job 777'\n"
        )
        self.touch("a.inp", "b.inp")
        Path("out").mkdir()
        Path("out/a.out").write_text("old")
        code, stdout, stderr = run_cue(["orca", "a.inp", "b.inp"])
        self.assertEqual(code, 0, stderr)
        self.assertIn("submitted array job 777", stdout)
        self.assertIn("backup:", stdout)
        self.assertEqual(Path(".a.manifest").read_text(), "a.inp\nb.inp\n")
        self.assertTrue(Path("out/backup/a.out.bck01").is_file())
        self.assertTrue(Path("submitted.slurm").read_text().startswith("#!/bin/bash"))

    def test_sbatch_failure_reported(self) -> None:
        self._install_fake_sbatch(
            "#!/bin/bash\necho 'sbatch: error: boom' >&2\nexit 1\n"
        )
        self.touch("a.inp")
        code, _, stderr = run_cue(["orca", "a.inp"])
        self.assertEqual(code, 1)
        self.assertIn("sbatch failed", stderr)
        self.assertIn("boom", stderr)

    def test_output_path_collision_reported(self) -> None:
        self.touch("a.inp")
        # a file named out blocks the output directory.
        Path("out").write_text("")
        code, _, stderr = run_cue(["orca", "a.inp"])
        self.assertEqual(code, 1)
        self.assertIn("cue: error", stderr)


class SallocTests(unittest.TestCase):
    def test_build_salloc_command(self) -> None:
        args = argparse.Namespace(
            cpus=4,
            memory=8,
            nodes=None,
            ntasks=None,
            time="2:00:00",
            partition=None,
        )
        site = cue.SiteDefaults(partition="chem")
        command = cue.build_salloc_command(args, site, "/bin/zsh")
        self.assertEqual(
            command,
            [
                "salloc",
                "--nodes=1",
                "--ntasks=1",
                "--cpus-per-task=4",
                "--mem=8gb",
                "--partition=chem",
                "--time=2:00:00",
                "srun",
                "--interactive",
                "--preserve-env",
                "--pty",
                "/bin/zsh",
            ],
        )


class DispatchTests(unittest.TestCase):
    def test_symlink_dispatch(self) -> None:
        cases = {
            "sorca": "orca",
            "sgaussian": "gaussian",
            "sint": "int",
            "submit-orca": "orca",
            "orca": "orca",
        }
        for program, expected in cases.items():
            command, rest = cue.split_command([program, "x.inp"])
            self.assertEqual(command, expected)
            self.assertEqual(rest, ["x.inp"])

    def test_plain_invocation(self) -> None:
        command, rest = cue.split_command(["cue", "orca", "x.inp"])
        self.assertEqual(command, "orca")
        self.assertEqual(rest, ["x.inp"])
        command, rest = cue.split_command(["cue"])
        self.assertIsNone(command)


if __name__ == "__main__":
    unittest.main()
