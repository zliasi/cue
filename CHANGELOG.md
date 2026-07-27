# changelog

## unreleased

- the project is renamed to cue: cue.py, cue.toml, ~/.config/cue,
  CUE_CONFIG_PATH, and .cue job files
- the generic runner task is renamed from exec to run
- new adf task config: the whole amsterdam modeling suite via the ams
  driver
- configurable output and slurm log directories: -o/--out/--outdir and
  -l/--log/--logdir flags, outdir/logdir job-file keys, per-task
  [execution] keys, and site-wide [defaults] keys
- new default directories: results in out/, slurm logs in log/,
  auto-records in <outdir>/.rec/ (were output/, output/, output/.record/)
- status scans every .rec/ store in the working directory and merges
  them; --dir reads one output directory only
- old slurm logs are backed up to <logdir>/backup/ before resubmission
- new task configs: nwchem, psi4, dftbplus, molpro, gromacs, qe, sharc,
  turbomole (+dscf/jobex variants), and a
  python-pyscf environment example
- stem = "parent" config key names jobs after the calculation directory
- configs combining stem = "parent" with [inject] rules are rejected at
  parse time (staged copies of same-named inputs would collide)
- help text lists -M/--manifest under submit

## 0.2.0 - 2026-07-06

- paired inputs via secondary_extensions, for dalton and dirac
- new software configs: dalton, dalton-embedded, dirac, cfour, python,
  fdmnes, fdmnes-serial, xtb, crest, stda, std2, std2-xtb, censo
- --set key=value overrides [paths] values per submission
- --args passes program arguments through the {args} placeholder (xtb)
- job files: cue <task> -f job.cue, cue template, automatic
  submission records in output/.record/, --record for visible records
- every submission is auto-recorded, also with --record; limit 1000
- -M/--manifest input lists, also as the manifest job-file key
- hist state filters (failed, timeout, cancelled, completed) and unified
  time windows (Xh/Xd/Xw/Xm)
- status command: per-project job fate from the records, --rerun writes
  job files covering exactly the failed tasks
- --after dependency shorthand and --parsable id-only output
- --mem-per-cpu allocation
- list --check config health check, --names and --partitions plain modes
- completion command: bash completion plus guarded s<task> aliases
- user-facing wording says task instead of software
- --inject-resources rewrites cpu/memory directives in staged input copies
- slurm commands: q/queue with stacking modifiers, p/partition with up and
  permission views, hist/history with ranges and monthly usage summaries,
  cancel, hold, release, mod/modify
- --record writes info command output to a timestamped file
- partitions key in cue.toml, maintained by "cue p permission"

## 0.1.0

- initial release
- engine: config discovery, validation, sbatch script rendering, submission
- software configs: orca, gaussian, gpaw, exec, plus example reference
- arrays with manifest and throttle for multiple inputs
- dependency passthrough, gpu, account, mail directives
- per-config node exclusion, optionally limited to one partition
- output backups counting up to .bck99
- interactive mode (cue int)
- init, list, link commands with shorthand symlinks (sorca, ...)
- config location chooseable with init --dir, remembered via a pointer
- flat <name>.toml configs found in ~/bin and any search directory
