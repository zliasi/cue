#!/usr/bin/env bash
# Gaussian 16 from /software/kemi, the site wrapper picks the build for the node.
# Put %nprocshared and %mem in the input to match -c and -m, cue does not edit
# inputs. For .gjf inputs pass --set ext=.gjf. Scratch files go to GAUSS_SCRDIR
# under /scratch, the checkpoint from %chk comes back next to the output.
#SBATCH --job-name=gaussian
#SBATCH --partition=katla_short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:10:00
#SBATCH --array=0-0%4
#SBATCH --output=log/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "home/lib/cue.sh"
cue_start "log/gaussian-20261015-160000.manifest" "out"
export GAUSS_SCRDIR="$CUE_SCRATCH"
# Retrieve runs on exit and on the time limit signal, cue_run's status is the job's.
cue_retrieve "*.chk"
cue_run /software/kemi/g16/g16 "$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM.out"
