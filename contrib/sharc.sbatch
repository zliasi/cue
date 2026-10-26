#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 sharc config, no golden from a steno run.
# SHARC trajectories. Each .inp sits next to its INITCONDS file and QM
# directory, which travel into scratch under sharc's fixed names. Set sharc=
# to the install. output.dat, output.lis, and restart come back with the stem
# as prefix.
#CUE ext=.inp cpus=4 memory=8 time=2-00:00:00 done={{stem}}.out
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
input_dir=$(dirname "$(realpath "$line")")
cue_start "{{manifest}}" "{{outdir}}"
export SHARC="{{sharc}}/bin" PATH="{{sharc}}/bin:$PATH" OMP_NUM_THREADS="{{cpus}}"
cp "$CUE_INPUT" input
[ -f "$input_dir/INITCONDS" ] && cp "$input_dir/INITCONDS" .
[ -d "$input_dir/QM" ] && cp -r "$input_dir/QM" .
cue_run "$SHARC/sharc.x" input >"$CUE_OUTDIR/$CUE_STEM.out" 2>&1
status=$?
[ -f output.dat ] && cp output.dat "$CUE_OUTDIR/$CUE_STEM-output.dat"
[ -f output.lis ] && cp output.lis "$CUE_OUTDIR/$CUE_STEM-output.lis"
[ -d restart ] && cp -r restart "$CUE_OUTDIR/$CUE_STEM-restart"
exit "$status"
