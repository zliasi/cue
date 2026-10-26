#!/usr/bin/env bash
# One worker run per input, the input is the worker's only argument.
# Name the worker with --set script=worker.py, or script= in cue.conf.
# The interpreter comes from python=, default python3. Point it at an env's
# python and its bin directory goes on PATH, which is what activation does.
# No scratch, the worker runs in the submission directory.
#SBATCH --job-name=python
#SBATCH --partition=katla_short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gpus=0
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --array=0-1%2
#SBATCH --output=log/%x_%A_%a.out
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "home/lib/cue.sh"
input=$(cue_line "log/python-20261015-160000.manifest") || exit 1
python=$(command -v "python3") || {
  echo "cue: no interpreter python3" >&2
  exit 1
}
PATH="$(dirname "$python"):$PATH"
export PATH
export OMP_NUM_THREADS="2"
export CUE_INPUT="$input" CUE_OUTDIR="out"
mkdir -p "$CUE_OUTDIR"
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
"$python" "worker.py" "$input"
