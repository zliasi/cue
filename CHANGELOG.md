# changelog

## 1.0.0

first template-based release, the interface is frozen from here, changes to flags need a reason in this file

- templates are real sbatch scripts with a #CUE line for defaults and {{placeholders}}, the TOML task configs are gone
- bin/cue is Python 3.9 standard library only, so it runs on every login node without conda
- settings merge from cue.conf in CUE_HOME, ~/.config/cue/cue.conf, the #CUE line, and flags, every key is a placeholder
- every submission is an array, with a manifest, the rendered script, and a resubmittable record in log/
- outputs that would be overwritten move to out/backup/<stamp>/ and move back when sbatch fails
- lib/cue.sh runs the job side: scratch under /scratch/<jobid>/<task>, cue_run, and cue_retrieve on exit and on the time limit signal
- shipped templates orca, gaussian, python, gpaw, and run, each verified by a real steno job with its rendered script as a golden
- contrib/ carries the remaining 0.2.0 programs as unverified templates
- flags -c -m -t -p -T -j -o -l -n --gpu --set --skip-done --dry-run --after -M -f, exit 1 for user errors and 2 for Slurm errors
- bash completion with cue completion --install, modulefile for group use on steno
- dropped: queue, history, cancel, hold, modify, interactive commands, input rewriting, scratch archiving
