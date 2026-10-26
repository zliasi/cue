#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 std2-xtb config, no golden from a steno run.
# std2 in xtb mode, xtb4stda builds the wavefunction from a geometry and no
# DFT run is needed. Set xtb4stda= to the binary and xtb4stda_home= to its
# parameter directory. More flags go through args.
#CUE ext=.xyz cpus=4 memory=4 time=04:00:00 e=7.0 args= std2=/software/kemi/std2/default/bin/std2 done={{stem}}.out
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
export XTB4STDAHOME="{{xtb4stda_home}}" OMP_NUM_THREADS="{{cpus}}" OMP_STACKSIZE=4G
ulimit -s unlimited
read -ra args <<<"{{args}}"
xtb4stda="{{xtb4stda}}"
"$xtb4stda" "$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM-xtb4stda.out" || exit
cue_run "{{std2}}" -xtb -e "{{e}}" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
[ -f tda.dat ] && cp tda.dat "$CUE_OUTDIR/$CUE_STEM-tda.dat"
exit "$status"
