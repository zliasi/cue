#!/bin/bash
#SBATCH --job-name=CeS8_inp
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="input/CeS8_inp.txt"
stem="CeS8_inp"

printf '%s\n' 'cue 0.2.0'
printf 'command     %s\n' 'cue fdmnes input/CeS8_inp.txt --dry-run'
printf 'job name    %s\n' CeS8_inp
printf 'job id      %s\n' "$SLURM_JOB_ID"
printf 'task        %s\n' fdmnes
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
. "/opt/fdmnes/mpirt/bin/intel64/mpivars.sh"
set -u

cp "$input_path" "$scratch/"
cd "$scratch"
input="$(basename "$input_path")"

rm -f "$input"
rsync -a --exclude=output --exclude=fdmfile.txt "$SLURM_SUBMIT_DIR/" .
printf '1\n\n%s\n' "$input_path" > fdmfile.txt
"/opt/fdmnes/mpirt/bin/intel64/mpirun" -np 4 "/opt/fdmnes/fdmnes_mpi_linux64" > "$SLURM_SUBMIT_DIR/out/$stem.out"
rsync -a --exclude=fdmfile.txt --exclude=output "$PWD/" "$SLURM_SUBMIT_DIR/out/"

cd "$SLURM_SUBMIT_DIR"
rm -rf "$scratch"

printf 'finished    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
