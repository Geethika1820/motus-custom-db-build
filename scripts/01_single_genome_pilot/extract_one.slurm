#!/bin/bash
#SBATCH --job-name=motus_marker_pilot
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot/extract_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot/extract_%j.err

set -euo pipefail

export PATH=/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH
OUT="/userapp/gpakala1/motus_custom_work/pilot/extraction_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python -u - "$OUT" <<'PY'
import logging
import os
import sys
from pathlib import Path
from fetchmgs import fetchmgs

logging.basicConfig(level=logging.INFO)
reference = Path(
    "/userapp/metabit/data/metalign_fulldb/organism_files/"
    "taxid_1000568_genomic.fna.gz"
)
output = Path(sys.argv[1])

fetchmgs.extraction_genomes(
    [reference], output, "genome",
    int(os.environ["SLURM_CPUS_PER_TASK"]), True
)

markers = list(output.rglob("*fetchMGs.fna"))
if not markers:
    raise RuntimeError("No marker FASTA produced; inspect logs.")

for path in markers:
    count = 0
    with path.open() as handle:
        for line in handle:
            if line.startswith(">"):
                count += 1
                print(line.rstrip())
    print(f"Extracted markers: {count}; file: {path}")

print("Marker extraction trial completed.")
PY
