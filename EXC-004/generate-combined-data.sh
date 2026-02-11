#!/usr/bin/env bash
set -euo pipefail

# --- Run from the script's directory (so paths are stable) ---
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

RAW_DIR="RAW-DATA"
OUT_DIR="COMBINED-DATA"
TRANSLATION_FILE="${RAW_DIR}/sample-translation.txt"

# Optional: set DRYRUN=1 to print actions without writing files
DRYRUN="${DRYRUN:-0}"

die() { echo "ERROR: $*" >&2; exit 1; }

run() {
  if [[ "$DRYRUN" == "1" ]]; then
    echo "[DRYRUN] $*"
  else
    "$@"
  fi
}

[[ -d "$RAW_DIR" ]] || die "Missing directory: $RAW_DIR"
[[ -f "$TRANSLATION_FILE" ]] || die "Missing file: $TRANSLATION_FILE"

run mkdir -p "$OUT_DIR"

# Get culture name (XXX) for a DNAxx from translation file.
get_culture() {
  local dna="$1"
  local culture
  culture="$(awk -v dna="$dna" 'BEGIN{FS="[ \t]+"} $1==dna {print $2; exit}' "$TRANSLATION_FILE")"
  [[ -n "$culture" ]] || die "No culture mapping found for $dna in $TRANSLATION_FILE"
  printf "%s" "$culture"
}

# Lookup completion + contamination for a bin stem like "bin-0" inside checkm.txt.
# checkm.txt (your dataset):
#   $1  = Bin Id (e.g. ms57_megahit_metabat_bin-0)
#   $13 = Completeness
#   $14 = Contamination
get_checkm_metrics() {
  local checkm_file="$1"
  local binstem="$2"

  local line
  line="$(grep -F "_$binstem" "$checkm_file" | head -n 1 || true)"
  [[ -n "$line" ]] || return 1

  awk '{ print $(NF-2), $(NF-1) }' <<<"$line"
}


# Rewrite FASTA headers so every defline is unique and includes culture prefix.
# New header format:
#   >CULTURE|OUTLABEL|seq000001|<original_header_without_>>
rewrite_fasta_headers() {
  local culture="$1"
  local outlabel="$2"
  local infile="$3"
  local outfile="$4"

  if [[ "$DRYRUN" == "1" ]]; then
    echo "[DRYRUN] awk rewrite headers: $infile -> $outfile (culture=$culture outlabel=$outlabel)"
    return 0
  fi

  awk -v c="$culture" -v lbl="$outlabel" '
    BEGIN{seq=0}
    /^>/{
      seq++
      sub(/^>/,"")
      printf(">%s|%s|seq%06d|%s\n", c, lbl, seq, $0)
      next
    }
    { print }
  ' "$infile" > "$outfile"
}

# --- Main loop over DNA directories ---
shopt -s nullglob
for dna_path in "${RAW_DIR}"/DNA*/; do
  [[ -d "$dna_path" ]] || continue
  dna="$(basename "$dna_path")"

  culture="$(get_culture "$dna")"

  bins_dir="${dna_path%/}/bins"
  checkm_file="${dna_path%/}/checkm.txt"
  gtdb_file="${dna_path%/}/gtdb.gtdbtk.tax"

  [[ -d "$bins_dir" ]] || die "Missing bins/ in $dna_path"
  [[ -f "$checkm_file" ]] || die "Missing checkm.txt in $dna_path"
  [[ -f "$gtdb_file" ]] || die "Missing gtdb.gtdbtk.tax in $dna_path"

  # Copy metadata
  run cp -f "$checkm_file" "${OUT_DIR}/${culture}-CHECKM.txt"
  run cp -f "$gtdb_file" "${OUT_DIR}/${culture}-GTDB-TAX.txt"

  mag_n=0
  bin_n=0

  # Process FASTAs
  for fasta in "$bins_dir"/*.fasta; do
    [[ -f "$fasta" ]] || continue
    base="$(basename "$fasta")"

    if [[ "$base" == "bin-unbinned.fasta" ]]; then
      out="${OUT_DIR}/${culture}_UNBINNED.fa"
      outlabel="${culture}_UNBINNED"
      rewrite_fasta_headers "$culture" "$outlabel" "$fasta" "$out"
      continue
    fi

    binstem="${base%.fasta}"  # e.g. bin-0
    metrics="$(get_checkm_metrics "$checkm_file" "$binstem")" \
      || die "No CheckM entry found for $dna ($binstem)"

    completion="$(awk '{print $1}' <<<"$metrics")"
    contamination="$(awk '{print $2}' <<<"$metrics")"

    # Decide MAG vs BIN (numeric compare using awk)
    if awk -v c="$completion" -v x="$contamination" 'BEGIN{exit ! (c>=50 && x<=5)}'; then
      type="MAG"
      mag_n=$((mag_n + 1))
      zzz="$(printf "%03d" "$mag_n")"
    else
      type="BIN"
      bin_n=$((bin_n + 1))
      zzz="$(printf "%03d" "$bin_n")"
    fi

    out="${OUT_DIR}/${culture}_${type}_${zzz}.fa"
    outlabel="${culture}_${type}_${zzz}"
    rewrite_fasta_headers "$culture" "$outlabel" "$fasta" "$out"
  done
done

echo "Done. Output written to: ${OUT_DIR}/"
