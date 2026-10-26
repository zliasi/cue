#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 std2 config, no golden from a steno run.
# std2 simplified TD-DFT on a molden file from a DFT run. ax must match the
# functional's exact exchange, 0.25 for PBE0, and the energy window e is in
# eV. More flags go through args, they come last and win.
#CUE ext=.molden cpus=4 memory=4 time=04:00:00 ax=0.25 e=7.0 args= std2=/software/kemi/std2/default/bin/std2 done={{stem}}.out
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
export OMP_NUM_THREADS="{{cpus}}" OMP_STACKSIZE=4G
ulimit -s unlimited
read -ra args <<<"{{args}}"
cue_run "{{std2}}" -f "$CUE_INPUT" -ax "{{ax}}" -e "{{e}}" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
[ -f tda.dat ] && cp tda.dat "$CUE_OUTDIR/$CUE_STEM-tda.dat"
exit "$status"
