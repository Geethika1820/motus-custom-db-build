#!/bin/bash
#SBATCH --job-name=motus_complete10
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/complete_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/complete_%j.err

set -euo pipefail
export PATH="/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH"

INPUT="/userapp/gpakala1/motus_custom_work/pilot10/run_4983776/pilot10_core_markers.fna"
OUT="/userapp/gpakala1/motus_custom_work/pilot10/complete_${SLURM_JOB_ID}"

test -s "$INPUT"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" \
  vsearch \
    --allpairs_global "$INPUT" \
    --acceptall \
    --threads "$SLURM_CPUS_PER_TASK" \
    --userout "$OUT/marker_pairs.tsv" \
    --userfields query+target+id+alnlen+mism+ids+ql+tl \
    > "$OUT/vsearch.out" 2> "$OUT/vsearch.err"

wc -l "$OUT/marker_pairs.tsv"
echo "Output directory: $OUT"
