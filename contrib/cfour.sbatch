#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 cfour config, no golden from a steno run.
# CFOUR reads ZMAT and GENBAS from its working directory, so each task gets a
# private copy of the binaries in scratch. A GENBAS next to the input wins over
# the shipped one.
#CUE ext=.inp cpus=1 memory=4 time=1-00:00:00 cfour=/software/kemi/CFOUR genbas=/software/kemi/CFOUR/basis/GENBAS done={{stem}}.out
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
own_genbas="$(dirname "$line")/GENBAS"
cue_start "{{manifest}}" "{{outdir}}"
export CFOUR="{{cfour}}" OMP_NUM_THREADS="{{cpus}}"
cp "{{cfour}}"/bin/* .
cp "{{cfour}}/basis/ECPDATA" .
if [ -f "$own_genbas" ]; then cp "$own_genbas" GENBAS; else cp "{{genbas}}" GENBAS; fi
cp "$CUE_INPUT" ZMAT
hostname >nodefile
cue_retrieve "ZMATnew" "FCMFINAL"
cue_run ./xcfour ./ZMAT ./GENBAS >"$CUE_OUTDIR/$CUE_STEM.out"
