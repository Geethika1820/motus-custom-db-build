# Build steps

These are the steps that actually ran, in order, with the scripts used. Every
Slurm script lives under `scripts/` and was submitted with `sbatch <script>`.
Scripts are verbatim copies and hard-code paths under
`/userapp/gpakala1/motus_custom_work/`. Results go to a new
`<name>_${SLURM_JOB_ID}` directory, and a script fails (`mkdir` without `-p`)
rather than overwrite an existing one.

Common environment for tool steps:

```bash
export PATH=/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH
```

Most steps are wrapped in `/usr/bin/time -v -o <dir>/resources.txt` so that
runtime and peak RSS are recorded.

**Steps with no saved script.** Steps 3b, 4 and 6 below have outputs but no
script on disk (searched `/userapp/gpakala1`, excluding conda and database
directories). Their inputs, outputs and the logic recovered from those outputs
are written down here, but the exact commands **cannot be reproduced** from
this repository. Writing these scripts is the top next step (see RESULTS.md).

---

## 0. Reference inventory (job 5038955)

`scripts/00_inventory/inventory.slurm` (1 CPU, 4 GB, system `python3`)

```bash
sbatch scripts/00_inventory/inventory.slurm
```

- Lists `organism_files/*.fna.gz` (199,807 files).
- Streams `db_info_fulldb_full.txt` (about 45M rows) and maps each file through
  the filename convention `taxid_<TaxID with '.'→'_'>_genomic.fna.gz`.
- A reference is a `PROKARYOTIC_CANDIDATE` when the first lineage field is
  `Bacteria` or `Archaea` and its metadata is consistent. It is
  `OUTSIDE_PROKARYOTIC_SCOPE` otherwise. It is `CONFLICTING_METADATA` or
  `NO_METADATA_MATCH` when those apply (both counts were 0).
- Outputs: `inventory.tsv` (36 MB, not committed) and
  `prokaryotic_candidates.txt` (173,119 paths, not committed). The committed
  summaries are `results/inventory/status_counts.tsv` and
  `results/inventory/domain_counts.tsv`.

## 1. Single-genome extraction trial (job 4979530)

`scripts/01_single_genome_pilot/extract_one.slurm` (4 CPU, 8 GB)

Runs `fetchmgs.extraction_genomes([genome], out, "genome", threads, True)` on
`taxid_1000568_genomic.fna.gz`. Result: 40 marker genes (all 40 fetchMGs COGs).

## 2. Assignment test against the official mOTUs 4.1 DB (job 4983750)

`scripts/02_assignment_pilot/assign_one.slurm` (4 CPU, **64 GB**)

```bash
motus classify -i genomes.txt -o assignments.tsv \
  -db /userapp/gpakala1/motus4_db/motus_dbs -t 4
```

Two earlier runs (4979551, 4983748, submitted with job name `bash` and 16 GB)
ended `OUT_OF_MEMORY`. The internal `vsearch --usearch_global` step was
killed with exit 137. The script that submitted them was not saved. This step
only reads the official database and does not change it.

## 3. 10-reference pilot: marker extraction

### 3a. Extraction (failed job 4983775, then job 4983776)

- `genomes.txt` lists 10 Metalign reference files.
- First attempt, `scripts/03_pilot10/extract.before_length_check.slurm` (job
  4983775), failed on `taxid_1000373_genomic.fna.gz`: Pyrodigal
  `ValueError: sequence must be at least 20000 characters (17126 found)`.
- Final version, `scripts/03_pilot10/extract.slurm` (job 4983776, 4 CPU, 8 GB):
  1. Sums the bases in each reference. Anything under 20,000 bp goes to
     `excluded_references.tsv`. Only `taxid_1000373` (17,078 bp, *Rosellinia
     necatrix quadrivirus 1*, a **virus**) was excluded. The script excludes by
     length, not by domain. The domain was confirmed by the inventory and
     taxonomy audits.
  2. Runs `fetchmgs.extraction_genomes` on the 9 remaining bacterial
     references.
  3. Writes `marker_summary.tsv` with the number of the 10 core COGs found per
     reference.

  Known quirk: in the excluded-row branch, the script writes `"\\t"` and
  `"\\n"` inside a quoted heredoc, so the excluded row went to stdout with a
  literal `\t` (see `extract_4983776.out`). The `.tsv` files on disk contain
  real tab characters, so they seem to have been corrected after the job. How
  is not recorded. Fix the escapes before reusing the script.

### 3b. Core-marker FASTA (no saved script)

`run_4983776/pilot10_core_markers.fna` (created 2026-11-17 02:24, after job
4983776) holds **79** sequences named `<reference>.<COG>`. It contains only the
10 core COGs from the 9 references: 5×8 + 9 + 3×10 = 79. The sequence IDs are
in `results/pilot10/extraction/pilot10_core_markers.ids.txt`.

## 4. All-vs-all marker comparison and provisional clustering

### 4a. Thresholded comparison (failed jobs 4983786 and 4983790, then job 4983979)

`scripts/03_pilot10/compare.slurm`

```bash
vsearch --allpairs_global pilot10_core_markers.fna --id 0.8 \
  --threads 4 --userout marker_pairs.tsv \
  --userfields query+target+id+alnlen+mism+ids+ql+tl
```

The first two attempts passed `--strand both`, which `--allpairs_global`
rejects. Job 4983979 produced 80 pairs. Its `genome_pair_summary.tsv` was
written later (2026-11-22 17:16) by an unsaved step. At `--id 0.8`,
cross-genus pairs show no valid alignments.

### 4b. Complete comparison (job 5038734)

`scripts/03_pilot10/compare_complete.slurm`. This is the same command as 4a
with `--acceptall` in place of `--id 0.8`. Output: `marker_pairs.tsv` with
3,081 lines (not committed, 317 KB).

### 4c. Genome clustering and marker grouping (no saved script)

These files in `complete_5038734/` were written after the job by unsaved
code:

| File | Content | What was checked |
|---|---|---|
| `genome_similarities.tsv` | per genome pair: shared core COGs, pairs passing coverage, combined identity | Shared-COG counts match `marker_pairs.tsv`. `100·Σids/Σalnlen` reproduces the identity exactly for all 10 within-cluster pairs but **not** for the 26 cross-cluster pairs. The exact formula is unknown. |
| `provisional_genome_clusters.tsv` | 9 references → `PILOT_001`…`PILOT_005` | Any threshold above 66.23% (the highest cross-cluster value) and at or below 98.10% (the lowest within-cluster value, 98.0961) gives this partition. The threshold actually used was not recorded. |
| `marker_groups/groups.tsv` + 47 FASTAs | one group per cluster × COG, with a per-COG cutoff (94.7–96.7%) | 47 groups = 8 (PILOT_001) + 9 + 10 + 10 + 10. The source of the cutoff values is not recorded. |
| `marker_group_cutoff_check.tsv` | minimum within-group identity vs. cutoff | MIN_IDENTITY values reproduce exactly from `marker_pairs.tsv`. One group failed: PILOT_001 COG0016 (min 95.0 < 96.7). |
| `retained_marker_groups/selection.tsv` + 47 FASTAs | marker retained/excluded | One marker removed: `taxid_100053_1 … COG0016`. Result: 78 retained sequences in 47 groups. |

## 5. 99% sequence reduction (job 5038785)

`scripts/03_pilot10/reduce99.slurm` (4 CPU, 4 GB). For each of the 47 retained
groups (the script asserts exactly 47):

```bash
vsearch --cluster_fast <group>.fna --id 0.99 --qmask none --notrunclabels \
  --threads 4 --centroids <group>.representatives.fna --uc <group>.uc
```

Result: 78 → **52** representative sequences (`results/pilot10/reduction/summary.tsv`).

## 6. Database assembly (no saved script)

The files in `pilot10/pilot_db/db_mOTU/` (created 2026-11-22 17:46–17:56) were
written by unsaved code in the mOTUs 4.1 layout:

| File | Content |
|---|---|
| `mOTUsv4.1-pilot.db.fna.gz` | 52 representative sequences renamed `PILOT_00N.MGC_<COG>_0000000001.MG_000000000k` |
| `mOTUsv4.1-pilot.map.tsv.gz` | `#MOTU MGC COG MG LENGTH ORIG`: 52 rows, 47 MGCs, 5 mOTUs |
| `mOTUsv4.1-pilot.db` | `database_version: 4.1-pilot`, `database_date: 2026-11-22`, `mgs: 52` |
| `mOTUsv4.1-pilot.genomes.tsv.gz` | 9 references → mOTU |
| `mOTUsv4.1-pilot.gtdb.taxonomy.{80mv,rep}.tsv.gz` | all ranks empty (`d__;p__;…;s__`) |
| `mOTUsv4.1-pilot.db.blocklist.gz` | empty |
| `db_mOTU.downloaded` | hand-written marker. Its text ("loading/profile tests pending") is now **out of date**, because those tests passed |
| `PILOT_LIMITATIONS.txt` | limitations note |

`pilot_db/cluster_source_taxonomy.tsv` (19:39) was added later from the
accession audit (step 9). It is **not** read by mOTUs.

Text copies of the small metadata files and sha256 checksums of every DB file
are in `results/pilot10/pilot_db_metadata/`.

## 7. BWA indexing (job 5038822)

`scripts/03_pilot10/index_pilot.slurm` (1 CPU, 4 GB). It refuses to run if any
index component already exists.

```bash
bwa index pilot_db/db_mOTU/mOTUsv4.1-pilot.db.fna.gz
# then checks that .amb .ann .bwt .pac .sa are all non-empty
```

## 8. Loading and synthetic-read test (failed job 5038938, then job 5038939)

- `scripts/03_pilot10/smoke.slurm` (job 5038938) stopped before profiling. It
  required markers of at least 450 bp, and
  `PILOT_002.MGC_COG0172…` is 297 bp.
- `scripts/03_pilot10/smoke_adaptive.slurm` (job 5038939):
  1. For every DB sequence longer than 150 bp, cuts 5 evenly spaced,
     error-free 150 bp reads with Q=`I` (52 × 5 = 260 reads).
  2. Profiles them:

```bash
motus profile -s synthetic.fastq -db pilot10/pilot_db -n PILOT_SMOKE \
  -o profile.tsv -t 4 -g 3 -y INSERT_SCALED
```

## 9. Source-taxonomy audits (jobs 5038940, 5038942)

- `scripts/03_pilot10/taxonomy_audit.slurm`: looks up each reference's TaxID
  in the metadata. TaxID `100053` returns 0 rows because the metadata uses
  `100053.0` to `100053.4`.
- `scripts/03_pilot10/accession_audit.slurm`: looks up every contig accession.
  All accessions of all 10 references matched (0 unmatched). This confirms
  that `taxid_1000373` is *Viruses* and the other 9 are *Bacteria*.

## 10. Full marker extraction (array job 5038978, in progress)

`scripts/04_full_build/extract.slurm` + `scripts/04_full_build/extract_batch.py`

```
#SBATCH --partition=qCPU24 --cpus-per-task=4 --mem=8G --time=12:00:00
#SBATCH --array=0-99%10
```

- Input: `inventory_5038955/prokaryotic_candidates.txt` (173,119 paths).
- Task `t` processes `files[t::100]` (1,732 references for tasks 0–18 and
  1,731 for tasks 19–99).
- For each reference: checks for duplicate contig IDs, counts bases, skips it
  if under 20,000 bp (`EXCLUDED_SHORT_GENOME_TRAINING`), runs fetchMGs in a
  temporary directory, and keeps only the 10 core COGs. It fails the reference
  if a core COG appears twice. It labels the reference `EXTRACTED_GE6` (≥6
  core COGs) or `EXTRACTED_LT6`.
- Outputs per batch: `markers.fna.gz`, `marker_provenance.tsv.gz`,
  `status.tsv`, `failures.log`. These stay as `*.partial` until the batch
  finishes, are then renamed, and `BATCH_COMPLETE` is written.

The job was **not** submitted, released, resumed or cancelled while this
repository was prepared. Only read-only `squeue`, `sacct` and `sstat` were
used.

## Not yet implemented

- Concatenating all 100 batch outputs.
- Full-scale all-vs-all comparison. At 173k genomes this needs a scalable
  approach (for example per-COG `--usearch_global` or clustering instead of
  `--allpairs_global`).
- Full genome clustering, marker grouping, 99% reduction, DB assembly, BWA
  indexing and loading test.
- CAMI read profiling and evaluation.
