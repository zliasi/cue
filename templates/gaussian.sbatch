#!/usr/bin/env bash
# Gaussian 16 from /software/kemi, the site wrapper picks the build for the node.
# Put %nprocshared and %mem in the input to match -c and -m, cue does not edit
# inputs. For .gjf inputs pass --set ext=.gjf. Scratch files go to GAUSS_SCRDIR
# under /scratch, the checkpoint from %chk comes back next to the output.
#CUE ext=.com cpus=8 memory=16 time=1-00:00:00 done={{stem}}.out
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
export GAUSS_SCRDIR="$CUE_SCRATCH"
# Retrieve runs on exit and on the time limit signal, cue_run's status is the job's.
cue_retrieve "*.chk"
cue_run /software/kemi/g16/g16 "$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM.out"
