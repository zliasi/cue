#!/bin/bash
#SBATCH --job-name=relax
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="relax.py"
stem="relax"
input="$input_path"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue gpaw relax.py --dry-run'
printf 'job name    %s\n' relax
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' gpaw
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 1
printf 'memory      %s\n' '2 GB'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

set +u
export OPENBLAS_NUM_THREADS=1
set -u

mpirun -np "$SLURM_NTASKS" gpaw python -- "$input"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
