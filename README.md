# motus-custom-db-build

Experimental work toward a **custom mOTUs-style marker-gene database** built
from the MetaBIT/Metalign full reference collection
(`/userapp/metabit/data/metalign_fulldb/organism_files`). The goal is to profile
samples (eventually CAMI benchmarks) with mOTUs against the same reference
genomes that the other profilers in our comparison use.

This repository is separate from `metabit-profiler-bench`. It holds only
scripts, documentation and small result summaries. Raw genomes, FASTQs,
marker FASTAs, database files and BWA indices are **not** committed (see
`.gitignore`).

> **This is not an official mOTUs database.** It is a locally assembled,
> experimental pilot that reuses the mOTUs 4.1 file layout so that the
> unmodified `motus profile` command can load it. See
> [Experimental vs. official build](#experimental-workflow-vs-official-motus-database-build).

## Current status (verified 2026-11-22, 21:20 UTC)

| Component | Status |
|---|---|
| Reference inventory (job 5038955) | **Done.** 199,807 reference files; 173,119 Bacteria/Archaea candidates; 26,688 outside prokaryotic scope. |
| 10-reference pilot: marker extraction (job 4983776) | **Done.** 10 references selected; 1 viral reference excluded (17,078 bp, below Pyrodigal's 20,000 bp training minimum); 9 bacterial references processed. |
| Pilot: clustering and marker grouping (from job 5038734 output) | **Done, provisional.** 5 provisional clusters, 47 marker groups. The script for this step was not saved (see BUILD_STEPS.md). |
| Pilot: 99% sequence reduction (job 5038785) | **Done.** 78 input sequences reduced to 52 representatives. |
| Pilot: database assembly | **Done, experimental.** No saved script (see BUILD_STEPS.md). |
| Pilot: BWA index (job 5038822) | **Done.** |
| Pilot: database loading and synthetic-read test (job 5038939) | **Passed.** DB loaded (5 mOTUs, 47 MGCs, 52 MGs); 260/260 synthetic reads aligned. **This does not show CAMI accuracy.** |
| Full marker extraction (array job 5038978, 173,119 candidates) | **In progress. Not finished.** Tasks 0–9 running (16,780 / 173,119 references processed at snapshot). Tasks 10–99 are **PENDING with reason `JobHeldUser`**, so they will not start until someone releases them. |
| Full clustering / reduction / DB assembly / indexing | **Not started.** No scripts written yet. |
| CAMI evaluation | **Not started.** |

Full numbers, runtimes and memory are in [RESULTS.md](RESULTS.md). Commands
and the procedure for each step are in [BUILD_STEPS.md](BUILD_STEPS.md).

## Software versions

All jobs ran with `PATH=/userapp/gpakala1/conda/envs/mOTUs4/bin:$PATH` on the
`qCPU24` Slurm partition.

| Software | Version | Source of version |
|---|---|---|
| mOTUs | 4.1.0 (`motus-4.1.0-pyhdfd78af_0`, bioconda) | conda-meta; `profile_stderr.txt` reports `mOTUs4:4.1.0` |
| fetchMGs | 2.1.3 (`fetchmgs-2.1.3-pyh106432d_0`) | conda-meta |
| Pyrodigal | 3.7.1 | conda-meta |
| VSEARCH | 2.32.0 | `vsearch --version`, job logs |
| BWA | 0.7.19-r1273 | `bwa`, `index_5038822_stderr.txt` |
| Python (mOTUs4 env) | 3.13.18 | `python --version` |
| Python for inventory/audit jobs | system `python3` (version not recorded) | scripts call `python3` without the env |
| Official reference DB used for the classify test | mOTUs DB 4.1, dated 2026-01-26 (124,300 mOTUs, 2,075,157 MGCs, 3,436,253 MGs) | `classify` log, `mOTUsv4.1.db` |
| Slurm | version not recorded | — |

## Local software modifications

**None to installed software.** Checked on 2026-11-22:

- `site-packages/motus/` and `site-packages/fetchmgs/` in the mOTUs4 env are
  identical (`diff -rq`, excluding `__pycache__`) to the unpacked conda
  package cache (`conda/pkgs/motus-4.1.0-pyhdfd78af_0`,
  `conda/pkgs/fetchmgs-2.1.3-pyh106432d_0`).
- `motus_custom_work/mOTUs-extender/` is a clean clone of
  `https://github.com/motu-tool/mOTUs-extender` at commit `59cb389`
  (`git status` shows no changes). **None of the scripts in this repository
  call mOTUs-extender.**

All custom behaviour comes from our own wrapper scripts, which call the
unmodified tools. They are:

- **Genome-size pre-filter.** References under 20,000 bp are excluded before
  calling `fetchmgs.extraction_genomes`. Without it, Pyrodigal training fails
  (`ValueError: sequence must be at least 20000 characters`, job 4983775).
- **Core-marker restriction.** Only the 10 COGs that mOTUs uses for profiling
  are kept: COG0012, COG0016, COG0018, COG0172, COG0215, COG0495, COG0525,
  COG0533, COG0541, COG0552. fetchMGs itself extracts up to 40 COGs (40 in
  the single-genome trial).
- **Hand-built database files.** `mOTUsv4.1-pilot.*` was written in the
  mOTUs 4.1 file layout without the official build pipeline, and includes a
  hand-written `db_mOTU.downloaded` marker file. The `.db` header lists only
  `database_version`, `database_date` and `mgs`. The official header also
  has MGC and mOTU counts and assigned/unassigned counts.

## Experimental workflow vs. official mOTUs database build

| Aspect | Official mOTUs 4.1 DB | This pilot |
|---|---|---|
| Who built it | mOTUs developers, official pipeline | Us, with ad-hoc scripts and some unsaved steps |
| Genomes | Curated genome collection | 9 Metalign reference files (pilot); 173,119 candidates (full build, in progress) |
| Metagenome-derived (unassigned) MGCs | Included (945,232 unassigned MGCs) | **None** |
| Blocklist | Populated | Empty file |
| Taxonomy | GTDB lineages | **Empty** GTDB ranks (`d__;p__;...;s__`). Source NCBI-style lineage is kept only in `cluster_source_taxonomy.tsv`, outside the DB |
| Species-level clustering | Official method and thresholds | Provisional grouping on combined marker identity. Linkage method and threshold not recorded (see RESULTS.md) |
| Per-COG cutoffs | Official calibrated values | Per-COG cutoffs applied (94.7–96.7%), but where the values came from is not recorded |
| Validation | Published benchmarks | Only a loading test and an error-free synthetic-read test |

Do not cite results from this database as mOTUs results without stating these
differences.

## Repository layout

```
README.md            project purpose, versions, status (this file)
BUILD_STEPS.md       commands and procedure for every step
RESULTS.md           verified results, runtime, peak RAM, limitations, next steps
scripts/
  00_inventory/          reference inventory (job 5038955)
  01_single_genome_pilot fetchMGs trial on one genome (job 4979530)
  02_assignment_pilot/   motus classify against official DB (job 4983750)
  03_pilot10/            10-reference pilot: extraction, comparison, reduction,
                         index, smoke tests, taxonomy/accession audits
  04_full_build/         full extraction array job (5038978) + batch script
results/             small summaries copied from motus_custom_work/
                     (TSV/text only; no sequences, BAMs, or indices)
```

Scripts are copied **verbatim** from `/userapp/gpakala1/motus_custom_work/`
and still contain absolute paths for that cluster layout.
