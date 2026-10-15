#!/usr/bin/env bash
#SBATCH --job-name=batch1
#SBATCH --partition=gpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=2-00:00:00
#SBATCH --array=0-0%1
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
source "home/lib/cue.sh"
cue_start "logs/batch1-20261015-160000.manifest" "results"
cue_run orca "$CUE_INPUT" > "$CUE_OUTDIR/$CUE_STEM.out"
cue_retrieve "*.gbw" "*.xyz"
