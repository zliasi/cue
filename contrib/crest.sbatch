#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 crest config, no golden from a steno run.
# Set crest= to the binary, xtb comes from /software/kemi. Modes go through
# args, for example --set args="--quick --alpb water". The best structure and
# the ensemble come back with the stem as prefix.
#CUE ext=.xyz cpus=8 memory=8 time=1-00:00:00 args= xtb_bin=/software/kemi/xtb/default/bin done={{stem}}.out
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
export PATH="{{xtb_bin}}:$PATH" OMP_NUM_THREADS="{{cpus}}" OMP_STACKSIZE=4G
ulimit -s unlimited
read -ra args <<<"{{args}}"
cue_run "{{crest}}" "$CUE_INPUT" -T "{{cpus}}" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
cp crest_best.xyz "$CUE_OUTDIR/$CUE_STEM-best.xyz"
cp crest_conformers.xyz "$CUE_OUTDIR/$CUE_STEM-conformers.xyz"
exit "$status"
