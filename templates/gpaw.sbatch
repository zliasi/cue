#!/usr/bin/env bash
# GPAW script per input, mpirun gpaw python with -n ranks and -c threads each.
# GPAW comes from a conda env, point python= at that env's interpreter, with
# --set or in ~/.config/cue/cue.conf, and its bin directory goes on PATH.
# No scratch, the script runs in the submission directory and its stdout
# goes to the output directory, GPAW's own txt goes where the script says.
#CUE ext=.py python=python3 ntasks=4 cpus=1 memory=8 time=1-00:00:00 done={{stem}}.out
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks={{ntasks}}
#SBATCH --cpus-per-task={{cpus}}
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
# GPAW built against openblas hangs with threaded blas.
export OPENBLAS_NUM_THREADS=1
# One node only, shared memory transport.
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=vader,self
export CUE_INPUT="$input" CUE_OUTDIR="{{outdir}}"
mkdir -p "$CUE_OUTDIR"
stem=$(basename "$input" .py)
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
mpirun -np "{{ntasks}}" gpaw python -- "$input" >"$CUE_OUTDIR/$stem.out"
