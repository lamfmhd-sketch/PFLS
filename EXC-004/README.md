# EXC-004 – Combined Data Generator

## Description

This Bash script processes all DNAxx directories inside `RAW-DATA/`
and generates a standardized output structure in `COMBINED-DATA/`.

For each DNAxx:

- Maps DNAxx → culture name using `sample-translation.txt`
- Copies:
  - checkm.txt → CULTURE-CHECKM.txt
  - gtdb.gtdbtk.tax → CULTURE-GTDB-TAX.txt
- Processes all FASTA files inside `bins/`
- Classifies bins as:
  - MAG if completeness ≥ 50 and contamination ≤ 5
  - BIN otherwise
- Renames files as:
  - CULTURE_MAG_###.fa
  - CULTURE_BIN_###.fa
  - CULTURE_UNBINNED.fa
- Rewrites FASTA headers to ensure:
  - Culture prefix included
  - Unique sequence identifiers

## Usage

Run from inside EXC-004:

```bash
bash generate-combined-data.sh
