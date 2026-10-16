#!/usr/bin/env bash
# ORCA 6.1.1 from /software/kemi with the openmpi the group's scripts use.
# Set %pal nprocs to the -c value in the input, cue does not edit inputs.
# One node and one task per core, openmpi counts Slurm tasks as slots.
#SBATCH --job-name=batch1
#SBATCH --partition=katla_short
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem=4G
#SBATCH --time=00:20:00
#SBATCH --array=0-0%1
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "home/lib/cue.sh"
cue_start "logs/batch1-20261015-160000.manifest" "results"
export PATH=/software/kemi/Orca/orca_6_1_1:/software/kemi/openmpi/openmpi-4.1.1/bin:$PATH
export LD_LIBRARY_PATH=/software/kemi/Orca/orca_6_1_1/lib:/software/kemi/openmpi/openmpi-4.1.1/lib
# One node only, so skip the infiniband transport and its warnings.
export OMPI_MCA_btl=^openib
# Retrieve runs on exit and on the time limit signal, cue_run's status is the job's.
cue_retrieve "*.gbw" "*.xyz" "*.hess" "*.interp" "*.allxyz" "*.nto" "*.cube"
cue_run /software/kemi/Orca/orca_6_1_1/orca "$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM.out"
