#!/bin/bash
#SBATCH --job-name=motus_assign_pilot
#SBATCH --partition=qCPU24
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=01:00:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/assignment_pilot/assign_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/assignment_pilot/assign_%j.err

set -euo pipefail
export PATH=/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH

OUT="/userapp/gpakala1/motus_custom_work/assignment_pilot/run_${SLURM_JOB_ID}"
mkdir "$OUT"

hostname

/usr/bin/time -v -o "$OUT/resources.txt" \
motus classify \
  -i /userapp/gpakala1/motus_custom_work/assignment_pilot/genomes.txt \
  -o "$OUT/assignments.tsv" \
  -db /userapp/gpakala1/motus4_db/motus_dbs \
  -t "$SLURM_CPUS_PER_TASK" \
  > "$OUT/classify.out" 2> "$OUT/classify.err"

test -s "$OUT/assignments.tsv"
cat "$OUT/assignments.tsv"
echo "Output directory: $OUT"
