#!/bin/bash
#SBATCH --job-name=mol
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=3gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="mol.xyz"
stem="mol"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue xtb mol.xyz -c 4 --mem-per-cpu 3 --dry-run'
printf 'job name    %s\n' mol
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' xtb
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 4
printf 'memory      %s\n' '3 GB per core'
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

scratch="/scratch/$SLURM_JOB_ID"
mkdir -p "$scratch"

set +u
export OMP_NUM_THREADS=4
export OMP_STACKSIZE=4G
ulimit -s unlimited
set -u

cp "$input_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"

"/opt/xtb/bin/xtb" "$input"  > "$SLURM_SUBMIT_DIR/out/$stem.out"

cd "$SLURM_SUBMIT_DIR"
tar -cJf "out/$stem.tar.xz" -C "$scratch" .
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
