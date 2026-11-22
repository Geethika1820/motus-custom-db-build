#!/bin/bash
#SBATCH --job-name=motus_taxonomy
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=01:00:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/taxonomy_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/taxonomy_%j.err

set -euo pipefail

OUT="/userapp/gpakala1/motus_custom_work/pilot10/taxonomy_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python3 -u - "$OUT" <<'PY'
import csv
import re
import sys
from collections import Counter
from pathlib import Path

base = Path("/userapp/gpakala1/motus_custom_work/pilot10")
output = Path(sys.argv[1])
metadata = Path(
    "/userapp/metabit/data/metalign_fulldb/db_info_fulldb_full.txt"
)

references = {}
for line in (base / "genomes.txt").read_text().splitlines():
    name = Path(line).name
    match = re.fullmatch(r"taxid_(\d+)(?:_\d+)?_genomic\.fna\.gz", name)
    if not match:
        raise RuntimeError(f"Unexpected reference filename: {name}")
    references[name] = match.group(1)

targets = set(references.values())
counts = Counter()
taxonomy = Counter()

print("Searching TaxIDs:", ", ".join(sorted(targets)), flush=True)

with metadata.open() as handle:
    reader = csv.reader(handle, delimiter="\t")
    header = [value.strip() for value in next(reader)]
    required = ["TaxID", "Lineage", "TaxID_Lineage"]
    if not all(column in header for column in required):
        raise RuntimeError(f"Unexpected metadata header: {header}")
    positions = [header.index(column) for column in required]

    for number, row in enumerate(reader, 1):
        if not row:
            continue
        if len(row) <= max(positions):
            raise RuntimeError(f"Malformed metadata row: {number + 1}")
        taxid = row[positions[0]].strip()
        if taxid in targets:
            lineage = row[positions[1]].strip()
            taxpath = row[positions[2]].strip()
            counts[taxid] += 1
            taxonomy[(taxid, lineage, taxpath)] += 1
        if number % 5000000 == 0:
            print(f"Scanned {number:,} rows", flush=True)

with (output / "source_taxonomy.tsv").open("w") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["SOURCE_TAXID", "LINEAGE", "TAXID_LINEAGE", "ROWS"])
    for (taxid, lineage, taxpath), count in sorted(taxonomy.items()):
        writer.writerow([taxid, lineage, taxpath, count])

with (output / "reference_taxids.tsv").open("w") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["REFERENCE", "SOURCE_TAXID", "MATCHING_METADATA_ROWS"])
    for name, taxid in sorted(references.items()):
        writer.writerow([name, taxid, counts[taxid]])

for taxid in sorted(targets):
    variants = sum(key[0] == taxid for key in taxonomy)
    print(f"TaxID {taxid}: {counts[taxid]:,} rows; {variants} lineage variants")

print("Taxonomy audit completed:", output)
PY
