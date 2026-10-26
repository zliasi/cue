#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 dftbplus config, no golden from a steno run.
# DFTB+ reads a fixed dftb_in.hsd from its working directory and takes no
# arguments, so the submission directory is mirrored into scratch, the input
# copied to the fixed name, and new files come back under outdir/stem. Keep
# the per calculation hsd files uniquely named. Set dftbplus= to the binary.
#CUE ext=.hsd cpus=4 memory=4 time=1-00:00:00 done={{stem}}/detailed.out
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
export OMP_NUM_THREADS="{{cpus}}"
rsync -a --exclude="{{outdir}}" --exclude="{{logdir}}" --exclude=dftb_in.hsd "$SLURM_SUBMIT_DIR/" .
cp "$CUE_INPUT" dftb_in.hsd
cue_run "{{dftbplus}}" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
mkdir -p "$CUE_OUTDIR/$CUE_STEM"
rsync -a --exclude=dftb_in.hsd "$CUE_SCRATCH/" "$CUE_OUTDIR/$CUE_STEM/"
exit "$status"
