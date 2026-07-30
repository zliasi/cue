#!/bin/bash
#SBATCH --job-name=h2o
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --exclude=node[001-004]
#SBATCH --export=NONE

set -euo pipefail

input_path="h2o.inp"
stem="h2o"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue orca h2o.inp --variant old --dry-run'
printf 'job name    %s\n' h2o
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' orca-old
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 1
printf 'memory      %s\n' '2 GB'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

scratch="/scratch/$SLURM_JOB_ID"
mkdir -p "$scratch"

cp "$input_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"

"/opt/orca-old/orca" "$input" > "$SLURM_SUBMIT_DIR/out/$stem.out"

cd "$SLURM_SUBMIT_DIR"
tar -cJf "out/$stem.tar.xz" -C "$scratch" .
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
