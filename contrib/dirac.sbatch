#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 dirac config, no golden from a steno run.
# DIRAC 21 through pam. The geometry is the .mol next to the input with the
# same stem. pam takes memory per process, --ag is the fair share of the
# allocation and --gb four fifths of it. Output files land in the output directory.
#CUE ext=.inp cpus=4 memory=8 time=1-00:00:00 pam=/software/kemi/DIRAC-21.0/build-intelmpi-2020.4.304-i8/pam
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
line=$(cue_line "{{manifest}}") || exit 1
mol=$(realpath "${line%.inp}.mol") || exit 1
cue_start "{{manifest}}" "{{outdir}}"
memory="{{memory}}"
cpus="{{cpus}}"
mem_per_cpu=$((memory / cpus))
pam_gb=$((mem_per_cpu * 4 / 5))
cue_retrieve "*.out" "*.h5"
cue_run "{{pam}}" --mpi="{{cpus}}" --gb="$pam_gb" --ag="$mem_per_cpu" --scratch="$CUE_SCRATCH" --mol="$mol" --inp="$CUE_INPUT"
