#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 psi4 config, no golden from a steno run.
# Set psi4= to the psi4 executable of its conda env. Threads follow -c, the
# memory line in the input should fit -m. Scratch files live under PSI_SCRATCH.
#CUE ext=.dat cpus=4 memory=8 time=1-00:00:00 done={{stem}}.out
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks=1
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
export PSI_SCRATCH="$CUE_SCRATCH" OMP_NUM_THREADS="{{cpus}}"
cue_run "{{psi4}}" -i "$CUE_INPUT" -o "$CUE_OUTDIR/$CUE_STEM.out" -n "{{cpus}}"
