addon_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$addon_root" || exit 1

status=0
for file in TreasuryTimeline.lua source/Money/Formatting.lua source/Database/Main.lua source/Reporting/DailySeries.lua source/Money/Repairs.lua source/Money/Tracker.lua source/UserInterface/ChartFrame.lua source/SlashCommands/Main.lua verification/run-self-check.lua; do
  printf "%-42s " "$file"
  if luac -p "$file"; then echo "syntax OK"; else status=1; fi
done

lua verification/run-self-check.lua || status=1
exit $status
