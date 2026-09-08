addon_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$addon_root" || exit 1

status=0

report_module_harness() {
  harness_script="$1"
  summary_lines="$2"
  if harness_output="$(bash "$harness_script")"; then
    echo "$harness_output" | tail -n "$summary_lines"
  else
    echo "$harness_output"
    status=1
  fi
}

count=0
while read -r file; do
  count=$((count+1))
  if [ ! -f "$file" ]; then echo "MISSING: $file"; status=1; continue; fi
  if ! luac -p "$file"; then echo "SYNTAX FAILED: $file"; status=1; fi
done < <(tr -d '\r' < EredarEngineering.toc | grep -E '\.lua$')
echo "syntax: $count files listed in the toc"
if [ "$count" -eq 0 ]; then
  echo "FAILED: the toc named no lua files, so the syntax check proved nothing"
  status=1
fi

echo "--- load order ---"
lua verification/run-load-order-check.lua || status=1

echo "--- module harnesses ---"
report_module_harness modules/TreasuryTimeline/verification/run-verification.sh 1
report_module_harness modules/CrestPlanner/verification/run-verification.sh 3

exit $status
