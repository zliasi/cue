#!/usr/bin/env bash
#CUE memory=4 time=01:00:00
#SBATCH --job-name={{name}}
#SBATCH --partition={{partition}}
#SBATCH --ntasks={{ntasks}}
#SBATCH --cpus-per-task={{cpus}}
#SBATCH --mem={{memory}}G
#SBATCH --time={{time}}
#SBATCH --gres=gpu:{{gpu}}
#SBATCH --array=0-{{last}}%{{throttle}}
#SBATCH --output={{logdir}}/%x_%A_%a.out
script=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "{{manifest}}")
bash "$script" > "{{outdir}}/$(basename "$script" .sh).out"
