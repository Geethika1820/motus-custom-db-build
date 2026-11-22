# Results

Every number below was checked against files in
`/userapp/gpakala1/motus_custom_work/` and against Slurm accounting on
2026-11-22. Copies of the supporting files are under `results/`. Anything not
recorded is marked **not measured**.

## 1. Reference inventory (job 5038955)

| | References |
|---|---|
| Reference files found | 199,807 |
| `PROKARYOTIC_CANDIDATE` (Bacteria 169,922 + Archaea 3,197) | **173,119** |
| `OUTSIDE_PROKARYOTIC_SCOPE` | 26,688 (Viruses 21,840; Eukaryota 4,794; Viroids 50; empty domain 4) |
| `CONFLICTING_METADATA` / `NO_METADATA_MATCH` | 0 / 0 |

Source: `results/inventory/`.

## 2. 10-reference pilot

### Reference selection

**Ten reference files were selected.** One was excluded and **nine bacterial
references** remained.

| Reference | Domain / organism | Bases | Core COGs found (of 10) |
|---|---|---|---|
| taxid_1000373 | **Virus**, *Rosellinia necatrix quadrivirus 1* | 17,078 | **excluded**: under Pyrodigal's 20,000 bp training minimum |
| taxid_100053_0 … _4 (5 files) | Bacteria, *Leptospira alexanderi* | 4.04–4.07 Mb | 8 each (missing COG0541, COG0552) |
| taxid_1000561 | Bacteria, *Pseudomonas aeruginosa* AES-1R | 6,267,620 | 9 (missing COG0016) |
| taxid_1000562 | Bacteria, *Streptococcus phocae* subsp. *salmonis* | 1,659,203 | 10 |
| taxid_1000565 | Bacteria, *Methyloversatilis universalis* FAM5 | 4,234,613 | 10 |
| taxid_1000568 | Bacteria, *Megasphaera* sp. UPII 199-6 | 1,640,787 | 10 |

The exclusion rule is **genome length**, not domain. The viral file is the
only one it removed. The accession audit matched 100% of contig accessions
for all 10 files and confirmed their domains.

Sources: `results/pilot10/extraction/`, `results/pilot10/accession_audit/`.

### Experimental pilot database contents

| | Count |
|---|---|
| Provisional clusters (mOTUs) | **5** (`PILOT_001` = 5 *L. alexanderi* files; `PILOT_002`–`005` = one reference each) |
| Marker groups (MGCs) | **47** |
| Core-marker sequences extracted | 79 |
| Sequences after removing one outlier (PILOT_001 COG0016, `taxid_100053_1`) | 78 |
| Representative sequences after 99% VSEARCH reduction (MGs) | **52** |

- Within PILOT_001, combined marker identity between genome pairs was
  98.10–99.81%. Between clusters it was 48.87–66.23%.
- Five PILOT_001 marker groups (COG0018, COG0172, COG0215, COG0495,
  COG0533) kept 2 representatives each at 99% identity. The other 42 groups
  kept 1 (5×2 + 42×1 = 52).
- `motus profile` reported on load: *"contains 5 mOTUs, 47
  markergeneclusters and 52 markergenes."*

Sources: `results/pilot10/clustering/`, `results/pilot10/reduction/`,
`results/pilot10/smoke_test/profile_stderr.txt`.

### Database-loading and synthetic-read test (job 5038939): passed

- The DB loaded as version `4.1-pilot`.
- **260 / 260 reads aligned (100.0%)**, with 0% multimappers.
- Profile (`-g 3 -y INSERT_SCALED`): all 5 mOTUs detected. Counts were 7, 5,
  5, 5, 5. Relative abundances were 0.2605, 0.1793, 0.1848, 0.1874, 0.1879.

**What this test shows:** the hand-built files are in a format `motus
profile` accepts, the BWA index works, and reads from every marker map back to
the right cluster.

**What it does not show:** the reads are error-free 150 bp fragments cut
directly from the database sequences, so mapping them back is circular. **This
test does not establish CAMI accuracy** or accuracy on any real or realistic
simulated data.

### Assignment test against the official mOTUs 4.1 DB (job 4983750)

`taxid_1000568_genomic.fna.gz` was assigned to `mOTUv4.0_050662` at 99.59%
similarity with 10 MGs. GTDB taxonomy: *Megasphaera_C lornae*. The source
metadata label is *Megasphaera* sp. UPII 199-6. This test used the official
database, not the pilot DB.

## 3. Full extraction, job 5038978: in progress, **not finished**

Snapshot taken 2026-11-22 21:20 UTC (`results/full_build/`):

| | |
|---|---|
| Array | `0-99%10` (100 tasks, max 10 concurrent), `qCPU24`, 4 CPU / 8 GB / 12 h per task |
| Running | tasks 0–9, started 2026-11-22 19:50 UTC, about 1 h 31 m elapsed |
| Pending | tasks 10–99, Slurm reason **`JobHeldUser`**. They will not start until released (`scontrol release`). They were **not** released here. |
| Completed batches | **0 / 100** (no `BATCH_COMPLETE` files yet) |
| References processed | **16,780 / 173,119 (9.7%)** |
| `EXTRACTED_GE6` / `EXTRACTED_LT6` | 16,031 / 747 |
| `EXCLUDED_SHORT_GENOME_TRAINING` | 2 |
| `FAILED` | 0 (all `failures.log` files empty) |

Estimate, not a measurement: tasks 0–9 were processing about 18 references
per minute each. Once released, the remaining 90 tasks would need about nine
more waves of about 1.6 h each, roughly 14–15 h of wall time at `%10`.

## 4. Runtime and peak memory

Times and peak RSS come from `/usr/bin/time -v` on the timed command ("Maximum
resident set size" is the largest single process, not a sum). Job state and
requested memory come from `sacct`.

| Step | Job | State | Wall time | Peak RSS | Mem requested |
|---|---|---|---|---|---|
| Inventory | 5038955 | COMPLETED | 1:23 | 246 MiB | 4 GB |
| Single-genome extraction | 4979530 | COMPLETED | 0:02.8 | 318 MiB | 8 GB |
| Classify (official DB) | 4979551 | OUT_OF_MEMORY | 1:26 | 14.0 GiB at kill | 16 GB |
| Classify (official DB) | 4983748 | OUT_OF_MEMORY | 1:25 | 13.9 GiB at kill | 16 GB |
| Classify (official DB) | 4983750 | COMPLETED | 5:26 | **22.8 GiB** | 64 GB |
| Pilot extraction, no length check | 4983775 | FAILED | 0:00.8 | 98 MiB | 8 GB |
| Pilot extraction (9 refs) | 4983776 | COMPLETED | 0:27.7 | 557 MiB | 8 GB |
| Core-marker FASTA assembly | — | no job | not measured | not measured | — |
| Compare `--id 0.8` (bad option) | 4983786, 4983790 | FAILED | <0:01 | not meaningful | 4 GB |
| Compare `--id 0.8` | 4983979 | COMPLETED | 0:01.2 | 305 MiB | 4 GB |
| Compare `--acceptall` | 5038734 | COMPLETED | 0:01.7 | 311 MiB | 4 GB |
| Genome clustering / marker grouping | — | no job | not measured | not measured | — |
| 99% reduction (47 groups) | 5038785 | COMPLETED | 0:01.2 | 222 MiB | 4 GB |
| DB assembly | — | no job | not measured | not measured | — |
| BWA index | 5038822 | COMPLETED | 0:00.12 | 3 MiB | 4 GB |
| Smoke test (450 bp rule) | 5038938 | FAILED (pre-check) | <0:01 | not measured | 4 GB |
| Smoke test: `motus profile` | 5038939 | COMPLETED | 0:00.55 | 177 MiB | 4 GB |
| Smoke test: read generation | 5038939 | COMPLETED | not measured | not measured | (same job) |
| Taxonomy audit | 5038940 | COMPLETED | 0:54 | 11.5 MiB | 2 GB |
| Accession audit | 5038942 | COMPLETED | 0:45 | 15 MiB | 2 GB |
| Full extraction, per task | 5038978_0–9 | RUNNING | about 1:31 so far | **not measured** (final). Interim `sstat` MaxRSS 2.41–2.55 GiB per task | 8 GB |
| Full extraction, total | 5038978 | RUNNING/HELD | not measured | not measured | — |

## 5. Limitations

1. **Experimental and not official.** Five clusters from nine references.
   There are no metagenome-derived (unassigned) MGCs and no blocklist
   screening.
2. **No taxonomy in the DB.** Every GTDB rank is empty, so profiles show
   `d__;p__;…;s__`. Source lineages exist only in
   `cluster_source_taxonomy.tsv`.
3. **Undocumented steps.** The core-marker FASTA, genome clustering, marker
   grouping, outlier removal and DB assembly were done with code that was not
   saved. The clustering threshold, the source of the per-COG cutoffs, and the
   exact cross-cluster identity formula are unknown.
4. **Provisional clustering.** The 5-cluster result is trivial for this set:
   identical-species files against unrelated genera. It does not test the
   clustering boundary.
5. **Circular smoke test.** It cannot measure accuracy, sensitivity, false
   positives or abundance error, and it says nothing about CAMI performance.
6. **Some references are incomplete.** Five *Leptospira* files lack COG0541
   and COG0552, and *P. aeruginosa* lacks COG0016. In the full run so far,
   747 references have fewer than 6 core COGs.
7. **Length-based exclusion.** References under 20 kb are dropped regardless
   of domain, which would include small genuine prokaryotic assemblies.
8. **The full rebuild is not finished.** Tasks 10–99 are held, and nothing
   after extraction exists yet for the full set.
9. **Out-of-date marker text.** `db_mOTU.downloaded` still says
   "loading/profile tests pending."

## 6. Next steps

1. Rewrite the unsaved steps (3b, 4c, 6 in BUILD_STEPS.md) as committed
   scripts, regenerate the pilot DB from them, and check it against the
   recorded sha256s.
2. Decide whether to release the held tasks of 5038978 (`scontrol release
   5038978`). This is the user's decision.
3. After all 100 batches report `BATCH_COMPLETE`, check the totals against
   173,119 and review `failures.log` and the `EXTRACTED_LT6` set.
4. Design a scalable comparison and clustering for about 173k genomes, and
   record the thresholds and per-COG cutoffs with their sources.
5. Populate taxonomy, add a blocklist, and consider unassigned MGCs.
6. Validate on realistic simulated reads (with errors, from genomes held out
   of the DB) before any CAMI run. Then run CAMI with stated caveats.
7. Fix the `\\t` escape quirk in `scripts/03_pilot10/extract.slurm`.
