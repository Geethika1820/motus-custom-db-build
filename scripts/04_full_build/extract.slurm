#!/bin/bash
#SBATCH --job-name=motus_full_extract
#SBATCH --partition=qCPU24
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --array=0-99%10
#SBATCH --output=/userapp/gpakala1/motus_custom_work/full_build/logs/extract_%A_%a.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/full_build/logs/extract_%A_%a.err

set -euo pipefail
export PATH="/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH"

ROOT="/userapp/gpakala1/motus_custom_work/full_build"

/usr/bin/time -v \
  -o "$ROOT/logs/resources_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt" \
  python -u "$ROOT/extract_batch.py"
