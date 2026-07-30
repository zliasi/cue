#!/bin/bash
#SBATCH --job-name=sp_hf-hgh2
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=20gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="sp_hf.inp"
secondary_path="hgh2.mol"
stem="sp_hf-hgh2"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue dirac sp_hf.inp hgh2.mol -c 4 -m 20 --dry-run'
printf 'job name    %s\n' sp_hf-hgh2
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' dirac
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 4
printf 'memory      %s\n' '20 GB'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

scratch="/scratch/$SLURM_JOB_ID"
mkdir -p "$scratch"

set +u
module purge
mem_per_cpu=$(( 20 / 4 ))
pam_gb=$(( mem_per_cpu * 4 / 5 ))
set -u

cp "$input_path" "$scratch/"
cp "$secondary_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"
secondary="$(basename "$secondary_path")"

"/opt/dirac/pam" --mpi=4 --gb=$pam_gb --ag=$mem_per_cpu --scratch="$scratch" --mol="$secondary" --inp="$input"

cd "$SLURM_SUBMIT_DIR"
tar -cJf "out/$stem.tar.xz" -C "$scratch" .
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
