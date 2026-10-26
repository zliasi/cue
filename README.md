# cue

cue: run a program on many inputs as one Slurm array job, from a template you can read.

A submission validates the inputs, renders the template, backs up outputs it would overwrite, calls sbatch, and writes a record for resubmission. The job copies its input to node scratch, runs there, streams the output back, and copies the files the template names back, also when the time limit is near. Nothing else.

## Installation

On steno:

```
module use /groups/kemi/liasi/share/modulefiles
module load cue
cue completion --install    # once, bash completion for your user
```

Elsewhere, clone the repository and put `bin` on your PATH, or set `CUE_HOME` to the clone. The engine needs Python 3.9 or newer and nothing else, the job side is bash 5.

## Usage

```
cue orca h2o.inp co2.inp         one array task per input
cue orca -M list.txt             inputs from a file, one per line, # comments allowed
cue orca --skip-done *.inp       drop inputs whose done file exists
cue orca --dry-run *.inp         print the script and run sbatch --test-only
cue -f log/orca-12345.cue        resubmit a record, flags on the command line win
cue list                         templates and the directory each comes from
cue show orca                    print a template
cue init orca                    copy a template to ~/.config/cue/templates
cue completion                   print the bash completion file
```

Flags:

- `-c` cores, `-m` memory in GB, `-t` time limit, `-p` partition, `-T` tasks running at once
- `-j` job name (default is the template name), `-o` output directory, `-l` log and record directory
- `-n` MPI ranks, `--gpu` one GPU, `--after JOBID` start after that job succeeds
- `--set KEY=VALUE` any placeholder of the template, repeatable

Every submission is an array, even for one input. Files land in `log/<name>-<stamp>.manifest`, `log/<name>-<stamp>.sbatch`, and `log/<name>-<jobid>.cue`, Slurm logs in `log/<name>_<jobid>_<task>.out`, program output in `out/<stem>.out`. Outputs of the same stem that already exist move to `out/backup/<stamp>/` first. Exit status is 0 on success, 1 for a mistake of yours, and 2 when Slurm rejects the job.

## Settings

Values merge in this order, later wins: `cue.conf` in `CUE_HOME`, `~/.config/cue/cue.conf`, the `#CUE` line of the template, flags. Every key is a template placeholder, so `partition=chem` in a conf file fills `{{partition}}`. Example `~/.config/cue/cue.conf`:

```
partition=katla_day
python=/groups/kemi/liasi/software/build/miniconda3/envs/atlas/bin/python
```

The second line points the python and gpaw templates at a conda environment, the interpreter's directory goes on PATH in the job.

## Templates

Shipped in `templates/`: orca, gaussian, python, gpaw, run. Each was verified by a real job on steno and its rendered script is kept as a golden in `tests/expected`.

- orca: ORCA 6.1.1 with the group's openmpi, one node, `%pal nprocs` in the input must match `-c`
- gaussian: g16 from /software/kemi, GAUSS_SCRDIR in scratch, the checkpoint comes back, `.gjf` inputs need `--set ext=.gjf`
- python: one worker run per input, `cue python --set script=worker.py -M items.txt`, the input is the worker's argument
- gpaw: `mpirun gpaw python` per script with `-n` ranks, no scratch
- run: any script with `bash`, or `--set launcher=python3`, no scratch

`contrib/` holds templates ported from the previous version without a verified run, for xtb, crest, cfour, molpro, nwchem, psi4, qe, gromacs, censo, dalton, dirac, adf, sharc, std2, dftbplus, fdmnes, and turbomole. Copy one to `~/.config/cue/templates/` and try it, the first line says what it still needs.

## Override a template

```
cue init orca
$EDITOR ~/.config/cue/templates/orca.sbatch
```

A template in your own directory shadows the shipped one with the same name, `cue list` shows which is in use. Keep the `#CUE` line, it holds the defaults and the input extension.

## Add a program

A template is a real sbatch script with a `#CUE key=value` line and `{{placeholders}}`. Copy the shipped template closest to your program, set `ext`, the resource defaults, and `done` on the `#CUE` line, and replace the program lines. `${var}` and `$(cmd)` pass through untouched, an unknown placeholder is an error at submission.

The job-side library `lib/cue.sh` gives:

- `cue_start MANIFEST OUTDIR`: reads the task's input, copies it to `/scratch/<jobid>/<task>`, exports `CUE_INPUT`, `CUE_STEM`, `CUE_OUTDIR`, `CUE_SCRATCH`, installs the traps, prints a header
- `cue_retrieve GLOB...`: files copied from scratch to the output directory now, on exit, and on the time limit signal
- `cue_run CMD...`: runs the program so the signal can interrupt it and returns its status
- `cue_line MANIFEST`: just the input for this task, for templates without scratch

Templates without scratch ignore `cue_start` and read `cue_line` instead. A template enters `templates/` here only with a golden from a real steno run, everything else sits in `contrib/`.

## Not in cue

Queue, history, cancel, hold, modify, and interactive work: use squeue, sacct, scancel, scontrol, and salloc. Input rewriting, `%pal`, `%nprocshared`, and `%mem` stay yours. Paired inputs and parent directory stems are bash in the template, see `contrib/dalton.sbatch` and `contrib/turbomole.sbatch`.

## Development

```
make check      black, ruff, mypy, shellcheck, shfmt
make test       unittest for the engine, bats for the library
make goldens    regenerate tests/expected, inspect the diff
```

CI runs both on Python 3.9, the login node version on steno, and 3.13.

## About

Zacharias Liasi, Department of Chemistry, University of Copenhagen. MIT license. The previous TOML-configured version is tagged 0.2.0.
