#!/usr/bin/env bash
#SBATCH --job-name=orca
#SBATCH --partition=chem
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=1-00:00:00
#SBATCH --array=0-1%4
#SBATCH --output=log/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
source "home/lib/cue.sh"
cue_start "log/orca-20261015-160000.manifest" "out"
cue_run orca "$CUE_INPUT" > "$CUE_OUTDIR/$CUE_STEM.out"
cue_retrieve "*.gbw" "*.xyz"
