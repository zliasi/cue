#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 gromacs config, no golden from a steno run.
# Single node thread build from /software/kemi, the .tpr from grompp is the
# whole input. mdrun names every file after the stem and finds GPUs from the
# allocation, pass --gpu for one. Continue a run with --set args="-cpi stem.cpt".
#CUE ext=.tpr cpus=8 memory=8 time=1-00:00:00 gpu=0 args= gmx_bin=/software/kemi/gromacs/grom/bin done={{stem}}.log
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --gpus={{gpu}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
#SBATCH --signal=B:USR1@120
#SBATCH --export=NONE
# shellcheck source=lib/cue.sh
source "{{cue_lib}}"
cue_start "{{manifest}}" "{{outdir}}"
# The GMXRC of the build sets the library path.
# shellcheck source=/dev/null
source "{{gmx_bin}}/GMXRC.bash"
export OMP_NUM_THREADS="{{cpus}}"
read -ra args <<<"{{args}}"
cue_retrieve "*.log" "*.edr" "*.xtc" "*.trr" "*.gro" "*.cpt"
cue_run gmx mdrun -s "$CUE_INPUT" -deffnm "$CUE_STEM" -ntomp "{{cpus}}" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.mdlog" 2>&1
