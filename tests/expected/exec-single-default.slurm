#!/bin/bash
#SBATCH --job-name=hello.sh
#SBATCH --output=log/%x.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2gb
#SBATCH --partition=chem
#SBATCH --export=NONE

set -euo pipefail

input_path="hello.sh"
stem="hello.sh"
input="$input_path"

mkdir -p "out" "log"

bash "$input"

sleep 2
sacct -n -j "$SLURM_JOB_ID" --format=JobID,JobName,MaxRSS,Elapsed,CPUTime --units=MB || true
