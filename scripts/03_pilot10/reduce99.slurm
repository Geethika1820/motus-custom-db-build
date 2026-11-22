#!/bin/bash
#SBATCH --job-name=motus_reduce99
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=/userapp/gpakala1/motus_custom_work/pilot10/reduce99_%j.out
#SBATCH --error=/userapp/gpakala1/motus_custom_work/pilot10/reduce99_%j.err

set -euo pipefail
export PATH="/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH"

OUT="/userapp/gpakala1/motus_custom_work/pilot10/reduced99_${SLURM_JOB_ID}"
mkdir "$OUT"

/usr/bin/time -v -o "$OUT/resources.txt" python -u - "$OUT" <<'PY'
import csv
import os
import subprocess
import sys
from pathlib import Path
from Bio import SeqIO

source = Path(
    "/userapp/gpakala1/motus_custom_work/pilot10/"
    "complete_5038734/retained_marker_groups"
)
output = Path(sys.argv[1])
files = sorted(source.glob("*.fna"))

if len(files) != 47:
    raise RuntimeError(f"Expected 47 marker groups; found {len(files)}")

total_input = total_output = 0
with (output / "summary.tsv").open("w") as summary:
    writer = csv.writer(summary, delimiter="\t")
    writer.writerow(["GROUP", "INPUT_SEQUENCES", "REPRESENTATIVES"])

    for path in files:
        name = path.stem
        representatives = output / f"{name}.representatives.fna"

        with (output / f"{name}.log").open("w") as log:
            subprocess.run([
                "vsearch",
                "--cluster_fast", str(path),
                "--id", "0.99",
                "--qmask", "none",
                "--notrunclabels",
                "--threads", os.environ["SLURM_CPUS_PER_TASK"],
                "--centroids", str(representatives),
                "--uc", str(output / f"{name}.uc")
            ], stdout=log, stderr=subprocess.STDOUT, check=True)

        before = sum(1 for _ in SeqIO.parse(path, "fasta"))
        after = sum(1 for _ in SeqIO.parse(representatives, "fasta"))
        if not 1 <= after <= before:
            raise RuntimeError(f"Invalid representative count: {name}")

        writer.writerow([name, before, after])
        total_input += before
        total_output += after
        print(f"{name}: {before} -> {after}", flush=True)

print(f"Groups processed: {len(files)}")
print(f"Input sequences: {total_input}")
print(f"Representative sequences: {total_output}")
print(f"Output: {output}")
PY
