# cue

Turns "run program X on these inputs" into one Slurm array job with
scratch, copy-back, backups and a record, rendered from a template
you can read. Nothing else.

Rewrite in progress. The previous version is tagged 0.2.0.

Rules

- bin/cue is Python 3.9 standard library only. Templates and the
  job-side library are bash 5.
- A template enters templates/ only with a golden from a real run on
  steno. Until then it sits in contrib/.
- No queue, history, cancel, hold, modify or interactive commands.
  No input rewriting.
