#!/usr/bin/env bash
#CUE ext=.inp cpus=8 memory=16 time=1-00:00:00 done={{stem}}.out
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
source "{{cue_lib}}"
cue_start "{{manifest}}" "{{outdir}}"
cue_run orca "$CUE_INPUT" > "$CUE_OUTDIR/$CUE_STEM.out"
cue_retrieve "*.gbw" "*.xyz"
