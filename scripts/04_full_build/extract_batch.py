import csv
import gc
import gzip
import logging
import os
import sys
import tempfile
import traceback
from pathlib import Path

from Bio import SeqIO
from fetchmgs import fetchmgs

logging.basicConfig(level=logging.WARNING)

manifest = Path(
    "/userapp/gpakala1/motus_custom_work/"
    "inventory_5038955/prokaryotic_candidates.txt"
)
root = Path("/userapp/gpakala1/motus_custom_work/full_build")
task = int(os.environ["SLURM_ARRAY_TASK_ID"])
job = os.environ["SLURM_ARRAY_JOB_ID"]
threads = int(os.environ["SLURM_CPUS_PER_TASK"])

files = [Path(x) for x in manifest.read_text().splitlines() if x.strip()]
selected = files[task::100]
output = root / f"extraction_{job}" / f"batch_{task:03d}"
output.mkdir(parents=True, exist_ok=False)

core = {
    "COG0012", "COG0016", "COG0018", "COG0172", "COG0215",
    "COG0495", "COG0525", "COG0533", "COG0541", "COG0552"
}
counts = {}

with gzip.open(output / "markers.fna.gz.partial", "wt") as fasta, \
     gzip.open(output / "marker_provenance.tsv.gz.partial", "wt") as provenance, \
     (output / "status.tsv.partial").open("w") as status, \
     (output / "failures.log").open("w") as failures:

    pw = csv.writer(provenance, delimiter="\t", lineterminator="\n")
    sw = csv.writer(status, delimiter="\t", lineterminator="\n")
    pw.writerow(["REFERENCE", "MARKER_ID", "COG", "LENGTH", "ORIGINAL_ID"])
    sw.writerow(["REFERENCE", "BASES", "CORE_FAMILIES", "STATUS"])

    for number, reference in enumerate(selected, 1):
        bases = 0
        found_count = 0
        result = "FAILED"

        try:
            seen = set()
            with gzip.open(reference, "rt") as handle:
                for record in SeqIO.parse(handle, "fasta"):
                    if record.id in seen:
                        raise ValueError(f"Duplicate sequence ID: {record.id}")
                    seen.add(record.id)
                    bases += len(record.seq)
            del seen

            if bases < 20000:
                result = "EXCLUDED_SHORT_GENOME_TRAINING"
            else:
                with tempfile.TemporaryDirectory(
                    prefix=f"motus_{task}_"
                ) as temporary:
                    temp = Path(temporary)
                    fetchmgs.extraction_genomes(
                        [reference], temp, "genome", threads, True
                    )
                    extracted = temp / f"{reference.name}.fetchMGs.fna"
                    if not extracted.is_file():
                        raise RuntimeError("Marker extraction output missing")

                    markers = {}
                    for record in SeqIO.parse(extracted, "fasta"):
                        cog = record.id.rsplit(".", 1)[-1]
                        if cog in core:
                            if cog in markers:
                                raise RuntimeError(f"Repeated core family: {cog}")
                            markers[cog] = (record.id, str(record.seq))

                    found_count = len(markers)
                    for cog, (original, sequence) in sorted(markers.items()):
                        identifier = f"{reference.name}.{cog}"
                        fasta.write(f">{identifier}\n{sequence}\n")
                        pw.writerow([
                            reference.name, identifier, cog,
                            len(sequence), original
                        ])

                    result = (
                        "EXTRACTED_GE6" if found_count >= 6
                        else "EXTRACTED_LT6"
                    )

        except Exception:
            failures.write(f"\nREFERENCE: {reference}\n")
            traceback.print_exc(file=failures)
            failures.flush()

        counts[result] = counts.get(result, 0) + 1
        sw.writerow([reference.name, bases, found_count, result])
        status.flush()
        gc.collect()

        if number % 25 == 0 or number == len(selected):
            print(
                f"Batch {task}: {number}/{len(selected)}; {counts}",
                flush=True
            )

for name in ("markers.fna.gz", "marker_provenance.tsv.gz", "status.tsv"):
    (output / f"{name}.partial").rename(output / name)

(output / "BATCH_COMPLETE").write_text(
    f"Processed {len(selected)} references\n{counts}\n"
)
print(f"Batch completed: {output}", flush=True)
