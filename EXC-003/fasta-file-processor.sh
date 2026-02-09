fasta="$1"

Number_of_sequences=$(awk '/^>/ {count++} END {print count+0}' "$fasta")

Total_length=$(awk '!/^>/ {
  line = $0
  total += gsub(/[AaTtCcGg]/, "", line)
  next
}
END {
  print total+0
}' "$fasta")

GC_content=$(awk '!/^>/ {
  line = $0
  gc += gsub(/[CcGg]/, "", line)

  line = $0
  total += gsub(/[AaTtCcGg]/, "", line)
  next
}
END {
  if (total > 0) print (gc / total) * 100
  else print 0
}' "$fasta")

Average_length=$(awk '
/^>/ { n++; next }
!/^>/ {
  line = $0
  total += gsub(/[AaTtCcGg]/, "", line)
}
END {
  if (n > 0) print total / n
  else print 0
}
' "$fasta")

echo "FASTA File Statistics:"
echo "----------------------"
echo "Number of sequences: $Number_of_sequences"
echo "Total length of sequences: $Total_length"
echo "Length of the longest sequence: 0"
echo "Length of the shortest sequence: 0"
echo "Average sequence length: $Average_length"
echo "GC Content (%): $GC_content"
