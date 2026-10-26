#!/usr/bin/env bash
# Unverified, carried from the 0.2.0 adf config, no golden from a steno run.
# Amsterdam Modeling Suite 2025, the ams driver runs the engine named in the
# input. SCMLICENSE must point at a license file, export it in your shell
# startup or add a line here. Temporary files stay in scratch.
#CUE ext=.ams ntasks=8 cpus=1 memory=16 time=1-00:00:00 ams_home=/software/kemi/AMS/ams2025.102-openmpi done={{stem}}.out
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
# The suite's own setup script defines AMSHOME, AMSBIN, and AMSRESOURCES.
# shellcheck source=/dev/null
source "{{ams_home}}/amsbashrc.sh"
export SCM_TMPDIR="$CUE_SCRATCH" NSCM="{{ntasks}}"
cue_run "$AMSBIN/ams" <"$CUE_INPUT" >"$CUE_OUTDIR/$CUE_STEM.out"
