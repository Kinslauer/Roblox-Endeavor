#!/usr/bin/env bash
# Builds both places with Rojo and publishes them to the Endeavor experience through Open Cloud.
# Needs ROBLOX_API_KEY (an Open Cloud key with Place Management: Write on the experience).
# Usage: tools/publish.sh [endeavor|front|all]   (default: all)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
ROJO="${ROJO:-rojo}"
UNIVERSE=10773835758
declare -A PLACES=( [endeavor]="120490278050491:default.project.json:build/Endeavor.rbxlx" [front]="81481823786216:war.project.json:build/Front.rbxlx" )
targets="${1:-all}"; [ "$targets" = all ] && targets="endeavor front"
mkdir -p build
for t in $targets; do
	IFS=: read -r id project out <<< "${PLACES[$t]}"
	"$ROJO" build "$project" -o "$out" >/dev/null
	for attempt in 1 2 3 4 5; do
		resp=$(curl -sS -m 300 -X POST -H "x-api-key: $ROBLOX_API_KEY" -H "Content-Type: application/xml" --data-binary @"$out" \
			"https://apis.roblox.com/universes/v1/$UNIVERSE/places/$id/versions?versionType=Published" -w "\n%{http_code}")
		code=${resp##*$'\n'}; body=${resp%$'\n'*}
		if [ "$code" = 200 ]; then echo "$t: published ($body)"; break; fi
		echo "$t: attempt $attempt got $code: $body" >&2
		[ "$attempt" = 5 ] && exit 1
		sleep $((attempt * 20))
	done
done
