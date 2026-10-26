#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 censo config, no golden from a steno run.
# CENSO refines a CREST ensemble through DFT rungs with ORCA underneath, so
# the ORCA setup from the orca template is repeated here. CENSO reads its own
# ~/.censo2rc. Set censo= to the binary. Options go through args.
#CUE ext=.xyz cpus=16 memory=32 time=2-00:00:00 args= done={{stem}}.out
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
export PATH=/software/kemi/Orca/orca_6_1_1:/software/kemi/openmpi/openmpi-4.1.1/bin:$PATH
export LD_LIBRARY_PATH=/software/kemi/Orca/orca_6_1_1/lib:/software/kemi/openmpi/openmpi-4.1.1/lib
export OMPI_MCA_btl=^openib OMP_NUM_THREADS=1
read -ra args <<<"{{args}}"
cue_run "{{censo}}" -i "$CUE_INPUT" --maxcores "{{cpus}}" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
