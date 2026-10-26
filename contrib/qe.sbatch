#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 qe config, no golden from a steno run.
# Quantum ESPRESSO pw.x from the kemi module. Set pseudo_dir= to the
# pseudopotentials. Wavefunctions written to outdir in &CONTROL stay in scratch
# and are deleted, give an absolute path there to keep them. Flags such as
# -nk 4 go through args.
#CUE ext=.in ntasks=8 cpus=1 memory=16 time=1-00:00:00 args= done={{stem}}.out
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
# Lmod is not initialized in a job started with --export=NONE.
# shellcheck source=/dev/null
source /usr/share/lmod/lmod/init/bash
module use /software/kemi/modulefiles
module load quantum-espresso/7.3.1
export ESPRESSO_PSEUDO="{{pseudo_dir}}" OMP_NUM_THREADS=1
read -ra args <<<"{{args}}"
cue_retrieve "*.xml"
cue_run mpirun -np "{{ntasks}}" pw.x -in "$CUE_INPUT" "${args[@]}" >"$CUE_OUTDIR/$CUE_STEM.out"
