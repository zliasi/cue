#!/usr/bin/env bash
# GPAW script per input, mpirun gpaw python with -n ranks and -c threads each.
# GPAW comes from a conda env, point python= at that env's interpreter, with
# --set or in ~/.config/cue/cue.conf, and its bin directory goes on PATH.
# No scratch, the script runs in the submission directory and its stdout
# goes to the output directory, GPAW's own txt goes where the script says.
#SBATCH --job-name=gpaw
#SBATCH --partition=katla_short
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --array=0-0%4
#SBATCH --output=log/%x_%A_%a.out
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "home/lib/cue.sh"
input=$(cue_line "log/gpaw-20261015-160000.manifest") || exit 1
python=$(command -v "/envs/atlas/bin/python") || {
  echo "cue: no interpreter /envs/atlas/bin/python" >&2
  exit 1
}
PATH="$(dirname "$python"):$PATH"
export PATH
export OMP_NUM_THREADS="1"
# GPAW built against openblas hangs with threaded blas.
export OPENBLAS_NUM_THREADS=1
# One node only, shared memory transport.
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=vader,self
export CUE_INPUT="$input" CUE_OUTDIR="out"
mkdir -p "$CUE_OUTDIR"
stem=$(basename "$input" .py)
echo "cue: job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date '+%F %T'), input $input"
mpirun -np "2" gpaw python -- "$input" >"$CUE_OUTDIR/$stem.out"
