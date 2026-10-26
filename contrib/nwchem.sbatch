#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 nwchem config, no golden from a steno run.
# Set nwchem= to the binary and load the MPI it was built with in a user copy
# of this template. The per-process heap is the memory directive in the input.
#CUE ext=.nw ntasks=8 cpus=1 memory=16 time=1-00:00:00 done={{stem}}.out
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks={{ntasks}}
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "{{cue_lib}}"
cue_start "{{manifest}}" "{{outdir}}"
export OMP_NUM_THREADS=1
cue_retrieve "*.movecs" "*.db"
cue_run mpirun -np "{{ntasks}}" "{{nwchem}}" "$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM.out"
