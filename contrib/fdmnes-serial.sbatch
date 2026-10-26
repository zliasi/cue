#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 fdmnes-serial config, no golden from a steno run.
# FDMNES serial binary with OpenMP threads, set fdmnes_dir= to the install.
# Same input handling as the fdmnes template.
#CUE ext=.txt cpus=4 memory=24 time=1-00:00:00 done={{stem}}/{{stem}}_bav.txt
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
cue_start "{{manifest}}" "{{outdir}}"
export OMP_NUM_THREADS="{{cpus}}"
rsync -a --exclude="{{outdir}}" --exclude="{{logdir}}" --exclude=fdmfile.txt "$SLURM_SUBMIT_DIR/" .
printf '1\n\n%s\n' "$line" >fdmfile.txt
cue_run "{{fdmnes_dir}}/fdmnes" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
mkdir -p "$CUE_OUTDIR/$CUE_STEM"
rsync -a --exclude=fdmfile.txt "$CUE_SCRATCH/" "$CUE_OUTDIR/$CUE_STEM/"
exit "$status"
