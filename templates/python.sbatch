#!/usr/bin/env bash
# One worker run per input, the input is the worker's only argument.
# Name the worker with --set script=worker.py, or script= in cue.conf.
# The interpreter comes from python=, default python3. Point it at an env's
# python and its bin directory goes on PATH, which is what activation does.
# No scratch, the worker runs in the submission directory.
#CUE python=python3 gpu=0 cpus=1 memory=4 time=1-00:00:00
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --gpus={{gpu}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "{{cue_lib}}"
input=$(cue_line "{{manifest}}") || exit 1
python=$(command -v "{{python}}") || {
  echo "cue: no interpreter {{python}}" >&2
  exit 1
}
PATH="$(dirname "$python"):$PATH"
export PATH
export OMP_NUM_THREADS="{{cpus}}"
export CUE_INPUT="$input" CUE_OUTDIR="{{outdir}}"
mkdir -p "$CUE_OUTDIR"
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
"$python" "{{script}}" "$input"
