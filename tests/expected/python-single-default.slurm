#!/bin/bash
#SBATCH --job-name=analysis
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="analysis.py"
stem="analysis"
input="$input_path"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue python analysis.py -c 4 --dry-run'
printf 'job name    %s\n' analysis
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' python
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 4
printf 'memory      %s\n' '2 GB'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

set +u
export OMP_NUM_THREADS=4
set -u

python3 "$input"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
