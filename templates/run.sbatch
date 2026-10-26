#!/usr/bin/env bash
# Any script per input, run in the submission directory, no scratch.
# The launcher is bash, change it with --set launcher=python3 or launcher=
# in cue.conf. Stdout goes to the output directory as <stem>.out.
#CUE launcher=bash gpu=0 cpus=1 memory=4 time=1-00:00:00 done={{stem}}.out
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
export OMP_NUM_THREADS="{{cpus}}"
export CUE_INPUT="$input" CUE_OUTDIR="{{outdir}}"
mkdir -p "$CUE_OUTDIR"
stem=$(basename "$input")
stem=${stem%.*}
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
launcher="{{launcher}}"
"$launcher" "$input" >"$CUE_OUTDIR/$stem.out"
