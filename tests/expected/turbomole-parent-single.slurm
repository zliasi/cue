#!/bin/bash
#SBATCH --job-name=benzene
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="benzene/control"
stem="benzene"
input="$input_path"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue turbomole benzene/control --dry-run'
printf 'job name    %s\n' benzene
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' turbomole
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 1
printf 'memory      %s\n' '2 GB'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

set +u
export TURBODIR="/opt/turbomole"
export PARA_ARCH=SMP
export PARNODES=1
set -u

cd "$(dirname "$input_path")"
ridft > "$SLURM_SUBMIT_DIR/output/$stem.out" 2>&1

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
