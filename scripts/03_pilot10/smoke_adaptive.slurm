#!/bin/bash
#SBATCH --job-name=motus_pilot_smoke
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/smoke_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/smoke_%j.err

set -euo pipefail
export PATH="/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH"

ROOT="/userapp/gpakala1/motus_custom_work/pilot10"
OUT="$ROOT/smoke_${SLURM_JOB_ID}"
mkdir "$OUT"

python - "$ROOT" "$OUT" <<'PY'
import gzip
import sys
from pathlib import Path
from Bio import SeqIO

root, output = map(Path, sys.argv[1:])
reference = root / "pilot_db/db_mOTU/mOTUsv4.1-pilot.db.fna.gz"
count = 0

with gzip.open(reference, "rt") as source, \
     (output / "synthetic.fastq").open("w") as dest:
    for record in SeqIO.parse(source, "fasta"):
        sequence = str(record.seq)
        if len(sequence) <= 150:
            print(f"SKIPPED short test marker: {record.id}, length={len(sequence)}")
            continue

        available = len(sequence) - 150
        margin = min(150, available // 2)
        first = margin
        last = available - margin

        for i in range(5):
            start = first + i * (last - first) // 4
            read = sequence[start:start + 150]
            count += 1
            dest.write(f"@smoke_{count}\n{read}\n+\n{'I' * 150}\n")

print(f"Generated {count} synthetic 150-base reads.")
PY

cd "$OUT"

/usr/bin/time -v -o "$OUT/profile_resources.txt" \
  motus profile \
    -s "$OUT/synthetic.fastq" \
    -db "$ROOT/pilot_db" \
    -n PILOT_SMOKE \
    -o "$OUT/profile.tsv" \
    -t "$SLURM_CPUS_PER_TASK" \
    -g 3 \
    -y INSERT_SCALED \
    > "$OUT/profile.out" 2> "$OUT/profile.err"

test -s "$OUT/profile.tsv"
test -s "$OUT/profile.tsv.relab"

echo "Profiling finished; checking abundance output:"
head -n 12 "$OUT/profile.tsv.relab"
echo "Output directory: $OUT"
