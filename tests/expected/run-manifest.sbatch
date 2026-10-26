#!/usr/bin/env bash
# Any script per input, run in the submission directory, no scratch.
# The launcher is bash, change it with --set launcher=python3 or launcher=
# in cue.conf. Stdout goes to the output directory as <stem>.out.
#SBATCH --job-name=run
#SBATCH --partition=katla_short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gpus=0
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --array=0-1%4
#SBATCH --output=log/%x_%A_%a.out
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "home/lib/cue.sh"
input=$(cue_line "log/run-20261015-160000.manifest") || exit 1
export OMP_NUM_THREADS="2"
export CUE_INPUT="$input" CUE_OUTDIR="out"
mkdir -p "$CUE_OUTDIR"
stem=$(basename "$input")
stem=${stem%.*}
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
launcher="bash"
"$launcher" "$input" >"$CUE_OUTDIR/$stem.out"
