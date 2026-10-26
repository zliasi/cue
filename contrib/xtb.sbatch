#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 xtb config, no golden from a steno run.
# Method flags go through args, for example --set args="--opt --gfn 2".
# Result files are prefixed with the stem through --namespace and copied back.
#CUE ext=.xyz cpus=4 memory=2 time=12:00:00 args= xtb=/software/kemi/xtb/default/bin/xtb done={{stem}}.out
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
export OMP_NUM_THREADS="{{cpus}}" MKL_NUM_THREADS="{{cpus}}" OMP_STACKSIZE=4G
ulimit -s unlimited
read -ra args <<<"{{args}}"
cue_retrieve "$CUE_STEM.xtbopt*" "$CUE_STEM.charges" "$CUE_STEM.wbo"
cue_run "{{xtb}}" "$CUE_INPUT" --namespace "$CUE_STEM" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
