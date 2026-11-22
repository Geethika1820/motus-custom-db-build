#!/bin/bash
#SBATCH --job-name=motus_inventory
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/inventory_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/inventory_%j.err

set -euo pipefail
OUT="/userapp/gpakala1/motus_custom_work/inventory_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python3 -u - "$OUT" <<'PY'
import csv
import sys
from collections import Counter
from pathlib import Path

source = Path("/userapp/metabit/data/metalign_fulldb/organism_files")
metadata = Path("/userapp/metabit/data/metalign_fulldb/db_info_fulldb_full.txt")
output = Path(sys.argv[1])

files = {p.name: p for p in source.glob("*.fna.gz")}
matched = {}
print(f"Reference files found: {len(files):,}", flush=True)

with metadata.open() as handle:
    reader = csv.reader(handle, delimiter="\t")
    header = [x.strip() for x in next(reader)]
    columns = [header.index(x) for x in
               ("TaxID", "Lineage", "TaxID_Lineage")]

    for number, row in enumerate(reader, 1):
        if not row:
            continue
        if len(row) <= max(columns):
            raise RuntimeError(f"Malformed metadata row: {number + 1}")

        taxid, lineage, taxpath = [row[i].strip() for i in columns]
        # Filename convention confirmed for the pilot references.
        name = f"taxid_{taxid.replace('.', '_')}_genomic.fna.gz"
        if name in files:
            annotation = (taxid, lineage, taxpath)
            if name not in matched:
                matched[name] = [annotation, 0, False]
            entry = matched[name]
            entry[1] += 1
            entry[2] |= annotation != entry[0]

        if number % 5000000 == 0:
            print(f"Scanned {number:,} metadata rows", flush=True)

counts = Counter()
with (output / "inventory.tsv").open("w") as table, \
     (output / "prokaryotic_candidates.txt").open("w") as manifest:
    writer = csv.writer(table, delimiter="\t", lineterminator="\n")
    writer.writerow([
        "REFERENCE", "SOURCE_ID", "DOMAIN",
        "METADATA_ROWS", "STATUS", "SOURCE_LINEAGE"
    ])

    for name, path in sorted(files.items()):
        if name not in matched:
            status = "NO_METADATA_MATCH"
            taxid = domain = lineage = ""
            rows = 0
        else:
            (taxid, lineage, taxpath), rows, conflict = matched[name]
            domain = lineage.split("|")[0]
            if conflict:
                status = "CONFLICTING_METADATA"
            elif domain in ("Bacteria", "Archaea"):
                status = "PROKARYOTIC_CANDIDATE"
                manifest.write(str(path) + "\n")
            else:
                status = "OUTSIDE_PROKARYOTIC_SCOPE"

        counts[status] += 1
        writer.writerow([name, taxid, domain, rows, status, lineage])

for status, count in sorted(counts.items()):
    print(f"{status}: {count:,}")
print("Saved inventory:", output)
PY
