#!/bin/bash
#SBATCH --job-name=motus_pilot_index
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/index_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/index_%j.err

set -euo pipefail
export PATH="/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH"

DB="/userapp/gpakala1/motus_custom_work/pilot10/pilot_db/db_mOTU"
FASTA="$DB/mOTUsv4.1-pilot.db.fna.gz"

test -s "$FASTA"
command -v bwa

for suffix in amb ann bwt pac sa; do
    if [[ -e "$FASTA.$suffix" ]]; then
        echo "Existing index component found; stopping: $FASTA.$suffix" >&2
        exit 1
    fi
done

/usr/bin/time -v -o "$DB/index_resources_${SLURM_JOB_ID}.txt" \
    bwa index "$FASTA"

for suffix in amb ann bwt pac sa; do
    test -s "$FASTA.$suffix"
done

echo "BWA index build completed; all five components exist."
du -sh "$DB"
