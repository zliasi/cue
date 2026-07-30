#!/bin/bash
#SBATCH --job-name=h2o
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16gb
#SBATCH --gpus=1
#SBATCH --partition=chem
#SBATCH --account=mylab
#SBATCH --time=1-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=user@example.com
#SBATCH --dependency=afterok:42
#SBATCH --export=NONE

set -euo pipefail

input_path="h2o.inp"
stem="h2o"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue orca h2o.inp -c 8 -m 16 -t 1-00:00:00 --account mylab --mail-type END,FAIL --mail-user user@example.com --dependency afterok:42 --gpu 1 --dry-run'
printf 'job name    %s\n' h2o
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' orca
printf 'input       %s\n' "$input_path"
printf 'node        %s\n' "$(hostname)"
printf 'partition   %s\n' "$SLURM_JOB_PARTITION"
printf 'cpus        %s\n' 8
printf 'memory      %s\n' '16 GB'
printf 'time limit  %s\n' 1-00:00:00
printf 'user        %s\n' "$USER"
printf 'started     %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "out" "log"

scratch="/scratch/$SLURM_JOB_ID"
mkdir -p "$scratch"

set +u
module purge
export PATH="/opt/orca:$PATH"
export OMP_NUM_THREADS=1
set -u

cp "$input_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"

"/opt/orca/orca" "$input" > "$SLURM_SUBMIT_DIR/out/$stem.out"

for ext in gbw xyz; do
  if [[ -f "$stem.$ext" ]]; then
    cp "$stem.$ext" "$SLURM_SUBMIT_DIR/out/"
    printf 'retrieved   %s\n' "$stem.$ext"
  fi
done

cd "$SLURM_SUBMIT_DIR"
tar -cJf "out/$stem.tar.xz" -C "$scratch" .
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
