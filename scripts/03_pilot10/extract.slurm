#!/bin/bash
#SBATCH --job-name=motus_extract10
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/extract_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/extract_%j.err

set -euo pipefail
export PATH=/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH

OUT="/userapp/gpakala1/motus_custom_work/pilot10/run_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python -u - "$OUT" <<'PY'
import logging
import os
import sys
from pathlib import Path
from Bio import SeqIO
from fetchmgs import fetchmgs

logging.basicConfig(level=logging.INFO)

manifest = Path("/userapp/gpakala1/motus_custom_work/pilot10/genomes.txt")
files = [Path(line.strip()) for line in manifest.read_text().splitlines()
         if line.strip()]
output = Path(sys.argv[1])
core = {
    "COG0012", "COG0016", "COG0018", "COG0172", "COG0215",
    "COG0495", "COG0525", "COG0533", "COG0541", "COG0552"
}

if len(files) != 10 or not all(p.is_file() for p in files):
    raise RuntimeError("Expected 10 accessible reference files.")

import gzip

eligible = []
excluded = {}
for reference in files:
    sequences = {}
    with gzip.open(reference, "rt") as handle:
        for record in SeqIO.parse(handle, "fasta"):
            sequences[record.id] = len(record.seq)
    total = sum(sequences.values())
    print(f"INPUT: {reference.name}: {total:,} bases", flush=True)
    if total < 20000:
        excluded[reference.name] = total
    else:
        eligible.append(reference)

with (output / "excluded_references.tsv").open("w") as handle:
    handle.write("REFERENCE\\tBASES\\tREASON\\n")
    for name, total in excluded.items():
        handle.write(f"{name}\\t{total}\\tBelow genome-training minimum\\n")

if not eligible:
    raise RuntimeError("No references meet the genome-training minimum.")

fetchmgs.extraction_genomes(
    eligible, output, "genome",
    int(os.environ["SLURM_CPUS_PER_TASK"]), True
)

with (output / "marker_summary.tsv").open("w") as summary:
    summary.write("REFERENCE\tCORE_FAMILIES\tMISSING_FAMILIES\n")
    for reference in files:
        if reference.name in excluded:
            row = f"{reference.name}\\tNA\\tEXCLUDED_BELOW_20000_BASES"
            summary.write(row + "\\n")
            print(row)
            continue
        marker_file = output / f"{reference.name}.fetchMGs.fna"
        if not marker_file.is_file():
            raise RuntimeError(f"Missing extraction output: {marker_file}")
        found = {
            record.id.rsplit(".", 1)[-1]
            for record in SeqIO.parse(marker_file, "fasta")
        } & core
        missing = ",".join(sorted(core - found)) or "-"
        row = f"{reference.name}\t{len(found)}\t{missing}"
        summary.write(row + "\n")
        print(row)

print("Extraction and marker summary completed.")
PY
