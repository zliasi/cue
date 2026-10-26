#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 molpro config, no golden from a steno run.
# Molpro starts its own MPI processes, -n ranks follow cue's -n. Memory is the
# memory card in the input, per process. Extra flags go through args.
#CUE ext=.inp ntasks=4 cpus=1 memory=8 time=1-00:00:00 args= molpro=/software/kemi/molpro/2021/bin/molpro done={{stem}}.out
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks={{ntasks}}
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
read -ra args <<<"{{args}}"
cue_retrieve "*.xml" "*.molden"
cue_run "{{molpro}}" -n "{{ntasks}}" -d "$CUE_SCRATCH" -o "$CUE_OUTDIR/$CUE_STEM.out" "${args[@]}" "$CUE_INPUT"
