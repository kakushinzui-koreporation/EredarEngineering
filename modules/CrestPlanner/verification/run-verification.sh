addon_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$addon_root" || exit 1
probe_file="/mnt/z/games/blizzard/World of Warcraft/_retail_/WTF/Account/310060125#1/SavedVariables/CrestPlanner.lua"
status=0
for file in $(find . -name '*.lua' | sort); do
  luac -p "$file" || { echo "SYNTAX FAILED: $file"; status=1; }
done
lua verification/run-self-check.lua "$probe_file" || status=1
exit $status
