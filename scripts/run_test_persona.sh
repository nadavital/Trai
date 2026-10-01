#!/bin/zsh
set -euo pipefail

# A dedicated simulator keeps the app's Keychain account separate from personal QA.
if [[ $# -lt 3 ]]; then
  print -u2 "Usage: SIMULATOR_UDID=<dedicated-UDID> $0 new|consistent|returning live|local-live|deterministic /path/to/Trai.app [optional-food-image]"
  exit 2
fi

persona="$1"
ai_mode="$2"
app_path="$3"
image_path="${4:-}"
simulator_udid="${SIMULATOR_UDID:-}"

case "$persona" in new|consistent|returning) ;; *) print -u2 "Unknown persona: $persona"; exit 2 ;; esac
case "$ai_mode" in live|local-live|deterministic) ;; *) print -u2 "Unknown AI mode: $ai_mode"; exit 2 ;; esac
[[ -n "$simulator_udid" ]] || { print -u2 "Set SIMULATOR_UDID to a dedicated Trai Persona QA simulator."; exit 2; }
[[ -d "$app_path" ]] || { print -u2 "App bundle does not exist: $app_path"; exit 2; }

sim_name="$(xcrun simctl list devices -j | /usr/bin/python3 -c 'import json,sys; udid=sys.argv[1]; print(next((d["name"] for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"] == udid), ""))' "$simulator_udid")"
[[ "$sim_name" == *"Trai Persona QA"* ]] || {
  print -u2 "Refusing to install on '$sim_name'. Use a dedicated simulator named Trai Persona QA."
  exit 2
}

xcrun simctl boot "$simulator_udid" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl install "$simulator_udid" "$app_path"

launch_args=(--test-persona "$persona" --test-persona-ai "$ai_mode" --disable-tab-prewarm)
if [[ -n "$image_path" ]]; then
  [[ -f "$image_path" ]] || { print -u2 "Image does not exist: $image_path"; exit 2; }
  app_data="$(xcrun simctl get_app_container "$simulator_udid" Nadav.Trai data)"
  mkdir -p "$app_data/Documents"
  staged_image="$app_data/Documents/TraiTestFood.${image_path:e}"
  cp "$image_path" "$staged_image"
  launch_args+=(--test-food-image-path "$staged_image")
fi

xcrun simctl launch --terminate-running-process "$simulator_udid" Nadav.Trai "${launch_args[@]}"
open -a Simulator
