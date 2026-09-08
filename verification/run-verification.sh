addon_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$addon_root" || exit 1

status=0
count=0
while read -r file; do
  count=$((count+1))
  if [ ! -f "$file" ]; then echo "MISSING: $file"; status=1; continue; fi
  if ! luac -p "$file"; then echo "SYNTAX FAILED: $file"; status=1; fi
done < <(grep -E '\.lua$' EredarEngineering.toc | tr -d '\r')
echo "syntax: $count files listed in the toc"

echo "--- load order ---"
lua verification/run-load-order-check.lua || status=1

echo "--- module harnesses ---"
bash modules/TreasuryTimeline/verification/run-verification.sh | tail -1 || status=1
bash modules/CrestPlanner/verification/run-verification.sh | tail -3 || status=1

exit $status
