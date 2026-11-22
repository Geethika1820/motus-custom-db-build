#!/bin/bash
#SBATCH --job-name=motus_accessions
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=01:00:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/accessions_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/accessions_%j.err

set -euo pipefail
OUT="/userapp/gpakala1/motus_custom_work/pilot10/accessions_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python3 -u - "$OUT" <<'PY'
import csv
import gzip
import sys
from collections import Counter, defaultdict
from pathlib import Path

base = Path("/userapp/gpakala1/motus_custom_work/pilot10")
output = Path(sys.argv[1])
owners = defaultdict(set)
expected = defaultdict(set)

for line in (base / "genomes.txt").read_text().splitlines():
    path = Path(line)
    with gzip.open(path, "rt") as handle:
        for text in handle:
            if text.startswith(">"):
                accession = text[1:].split()[0]
                owners[accession].add(path.name)
                expected[path.name].add(accession)

found = defaultdict(set)
annotations = defaultdict(set)

metadata = "/userapp/metabit/data/metalign_fulldb/db_info_fulldb_full.txt"
with open(metadata) as handle:
    reader = csv.reader(handle, delimiter="\t")
    header = [x.strip() for x in next(reader)]
    accession_col = header.index("Accesion")
    columns = [header.index(x) for x in
               ("TaxID", "Lineage", "TaxID_Lineage")]

    for number, row in enumerate(reader, 1):
        if not row:
            continue
        accession = row[accession_col].strip()
        if accession in owners:
            annotation = tuple(row[i].strip() for i in columns)
            for reference in owners[accession]:
                found[reference].add(accession)
                annotations[(reference, *annotation)].add(accession)
        if number % 5000000 == 0:
            print(f"Scanned {number:,} rows", flush=True)

with (output / "taxonomy_by_accession.tsv").open("w") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["REFERENCE", "SOURCE_TAXID", "LINEAGE",
                     "TAXID_LINEAGE", "MATCHED_ACCESSIONS"])
    for key, accessions in sorted(annotations.items()):
        writer.writerow([*key, len(accessions)])

with (output / "coverage.tsv").open("w") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["REFERENCE", "TOTAL_ACCESSIONS", "MATCHED", "UNMATCHED"])
    for reference in sorted(expected):
        total = len(expected[reference])
        matched = len(found[reference])
        row = [reference, total, matched, total - matched]
        writer.writerow(row)
        print("\t".join(map(str, row)))

print("Accession-based taxonomy audit completed:", output)
PY
