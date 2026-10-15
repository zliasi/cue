#!/usr/bin/env bash
#SBATCH --job-name=run
#SBATCH --partition=chem
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --gres=gpu:1
#SBATCH --array=0-1%4
#SBATCH --output=log/%x_%A_%a.out
script=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "log/run-20261015-160000.manifest")
bash "$script" > "out/$(basename "$script" .sh).out"
