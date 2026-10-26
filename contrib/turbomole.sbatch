#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 turbomole configs, no golden from a steno run.
# A Turbomole calculation is a directory prepared with define, pass its control
# file. The program runs inside that directory, no scratch, and the job is named
# after the directory. program= picks ridft, dscf, or jobex, extra flags such as
# -ri -c 200 for jobex go through args.
#CUE cpus=4 memory=8 time=1-00:00:00 program=ridft args= turbodir=/software/kemi/TURBOMOLE
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "{{cue_lib}}"
control=$(cue_line "{{manifest}}") || exit 1
calc_dir=$(dirname "$(realpath "$control")")
stem=$(basename "$calc_dir")
outdir=$(realpath -m "{{outdir}}")
mkdir -p "$outdir"
export TURBODIR="{{turbodir}}"
# The suite's own setup script puts its binaries on PATH.
# shellcheck source=/dev/null
source "$TURBODIR/Config_turbo_env"
export PARA_ARCH=SMP PARNODES="{{cpus}}" OMP_NUM_THREADS="{{cpus}}"
read -ra args <<<"{{args}}"
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), calculation $calc_dir"
cd "$calc_dir" || exit 1
program="{{program}}"
"$program" "${args[@]}" >"$outdir/$stem.out" 2>&1
