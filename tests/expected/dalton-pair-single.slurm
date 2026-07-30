#!/bin/bash
#SBATCH --job-name=hf-water
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="hf.dal"
secondary_path="water.mol"
stem="hf-water"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue dalton hf.dal water.mol --dry-run'
printf 'job name    %s\n' hf-water
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' dalton
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

set +u
module purge
dalton_bin="/opt/dalton/dalton32"
if [ 2 -gt 16 ]; then
  dalton_bin="/opt/dalton/dalton64"
fi
export DALTON_TMPDIR="$scratch"
set -u

cp "$input_path" "$scratch/"
cp "$secondary_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"
secondary="$(basename "$secondary_path")"

"$dalton_bin" -d -np 1 -gb 2 -t "$scratch" -dal "$input" -mol "$secondary" -o "$SLURM_SUBMIT_DIR/out/$stem.out"

cd "$SLURM_SUBMIT_DIR"
tar -cJf "out/$stem.tar.xz" -C "$scratch" .
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
