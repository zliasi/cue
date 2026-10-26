#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 dalton config, no golden from a steno run.
# Dalton 2020, 64 bit integer parallel build. A geometry file next to the
# input with the same stem and .mol suffix is passed as the molecule, without
# one the .dal must carry the geometry.
#CUE ext=.dal cpus=4 memory=8 time=1-00:00:00 dalton=/software/kemi/DALTON2020/dalton/build-64-intel-20.0.4-par/dalton done={{stem}}.out
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
mol=$(realpath -m "${line%.dal}.mol")
cue_start "{{manifest}}" "{{outdir}}"
export DALTON_TMPDIR="$CUE_SCRATCH"
molarg=()
[ -f "$mol" ] && molarg=(-mol "$mol")
cue_run "{{dalton}}" -d -np "{{cpus}}" -gb "{{memory}}" -t "$CUE_SCRATCH" -dal "$CUE_INPUT" "${molarg[@]}" -o "$CUE_OUTDIR/$CUE_STEM.out"
