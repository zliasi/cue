#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 fdmnes config, no golden from a steno run.
# FDMNES parallel binary with its bundled Intel MPI runtime, set fdmnes_dir=
# to the install. Pass the calculation inputs, never fdmfile.txt. The
# submission directory is mirrored into scratch so relative cif references
# keep working, and new files come back under outdir/stem.
#CUE ext=.txt ntasks=4 cpus=1 memory=24 time=1-00:00:00 done={{stem}}/{{stem}}_bav.txt
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
line=$(cue_line "{{manifest}}") || exit 1
cue_start "{{manifest}}" "{{outdir}}"
# The runtime's own script sets its paths.
# shellcheck source=/dev/null
source "{{fdmnes_dir}}/mpirt/bin/intel64/mpivars.sh"
rsync -a --exclude="{{outdir}}" --exclude="{{logdir}}" --exclude=fdmfile.txt "$SLURM_SUBMIT_DIR/" .
printf '1\n\n%s\n' "$line" >fdmfile.txt
cue_run "{{fdmnes_dir}}/mpirt/bin/intel64/mpirun" -np "{{ntasks}}" "{{fdmnes_dir}}/fdmnes_mpi_linux64" >"$CUE_OUTDIR/$CUE_STEM.out"
status=$?
mkdir -p "$CUE_OUTDIR/$CUE_STEM"
rsync -a --exclude=fdmfile.txt "$CUE_SCRATCH/" "$CUE_OUTDIR/$CUE_STEM/"
exit "$status"
