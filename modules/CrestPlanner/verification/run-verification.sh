addon_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$addon_root" || exit 1
probe_file="/mnt/z/games/blizzard/World of Warcraft/_retail_/WTF/Account/310060125#1/SavedVariables/CrestPlanner.lua"
status=0
for file in $(grep '^source/' CrestPlanner.toc) CrestPlanner.lua verification/run-self-check.lua; do
  printf "%-52s " "$file"
  if luac -p "$file"; then echo "syntax OK"; else status=1; fi
done
echo "--- verification ---"
lua verification/run-self-check.lua "$probe_file" || status=1
exit $status
