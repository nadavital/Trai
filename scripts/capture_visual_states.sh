#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT_DIR/tools/visual_states/manifest.json"
OUTPUT_BASE="$ROOT_DIR/artifacts/visual-states"
DERIVED_DATA_PATH="${VISUAL_STATE_DERIVED_DATA_PATH:-/tmp/TraiVisualStateCaptureDerived}"
DESTINATION="${VISUAL_STATE_DESTINATION:-}"
CONFIG_PATH="/tmp/trai-visual-state-capture-config.json"
SELECTED_GROUPS=""
IDS=()

usage() {
  cat <<'EOF'
Usage:
  scripts/capture_visual_states.sh [--all]
  scripts/capture_visual_states.sh --group core
  scripts/capture_visual_states.sh dashboard live-workout

Outputs are written to artifacts/visual-states/<timestamp>/ and mirrored by
artifacts/visual-states/latest/. They are intentionally gitignored.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      SELECTED_GROUPS=""
      IDS=()
      shift
      ;;
    --group)
      SELECTED_GROUPS="${2:-}"
      if [[ -z "$SELECTED_GROUPS" ]]; then
        echo "Missing value for --group" >&2
        exit 2
      fi
      shift 2
      ;;
    --manifest)
      MANIFEST="${2:-}"
      if [[ -z "$MANIFEST" ]]; then
        echo "Missing value for --manifest" >&2
        exit 2
      fi
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      if [[ -z "$DESTINATION" ]]; then
        echo "Missing value for --destination" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      IDS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "Visual-state manifest not found: $MANIFEST" >&2
  exit 1
fi

if [[ -z "$SELECTED_GROUPS" && ${#IDS[@]} -eq 0 ]]; then
  SELECTED_GROUPS="core"
fi

if [[ ${#IDS[@]} -gt 0 ]]; then
  IDS_CSV="$(IFS=,; echo "${IDS[*]}")"
else
  IDS_CSV=""
fi
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUTPUT_BASE/$RUN_ID"
mkdir -p "$RUN_DIR"

if [[ -z "$DESTINATION" ]]; then
  SIMCTL_DEVICES_JSON="$(xcrun simctl list devices available -j)"
  DESTINATION="$(SIMCTL_DEVICES_JSON="$SIMCTL_DEVICES_JSON" /usr/bin/python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["SIMCTL_DEVICES_JSON"])
devices = [
    device
    for runtime_devices in data.get("devices", {}).values()
    for device in runtime_devices
    if device.get("isAvailable", True) and device.get("name", "").startswith("iPhone")
]
booted = next((device for device in devices if device.get("state") == "Booted"), None)
chosen = booted or (devices[0] if devices else None)
if not chosen:
    raise SystemExit("No available iPhone simulator found")
print(f"platform=iOS Simulator,id={chosen['udid']}")
PY
)"
fi

echo "Capturing Trai visual states"
echo "  manifest: $MANIFEST"
echo "  output:   $RUN_DIR"
echo "  group:    ${SELECTED_GROUPS:-<none>}"
echo "  ids:      ${IDS_CSV:-<all matching>}"
echo "  dest:     $DESTINATION"
echo "  derived:  $DERIVED_DATA_PATH"

trap 'rm -f "$CONFIG_PATH"' EXIT
/usr/bin/python3 - "$CONFIG_PATH" "$MANIFEST" "$RUN_DIR" "$SELECTED_GROUPS" "$IDS_CSV" <<'PY'
import json
import sys
import time

config_path, manifest, output_dir, groups, ids = sys.argv[1:]
with open(config_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "enabled": True,
            "createdAt": time.time(),
            "manifestPath": manifest,
            "outputPath": output_dir,
            "groups": groups,
            "ids": ids,
        },
        handle,
    )
PY

xcodebuild test \
  -project "$ROOT_DIR/Trai.xcodeproj" \
  -scheme TraiTests \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:TraiUITests/VisualStateCaptureTests/testCaptureVisualStates

/usr/bin/python3 "$ROOT_DIR/scripts/generate_visual_state_index.py" \
  --manifest "$MANIFEST" \
  --output-dir "$RUN_DIR" \
  --ids "$IDS_CSV" \
  --groups "$SELECTED_GROUPS"

rm -f "$OUTPUT_BASE/latest"
ln -s "$RUN_DIR" "$OUTPUT_BASE/latest"

echo "Visual states captured:"
echo "  $RUN_DIR/index.html"
echo "  $OUTPUT_BASE/latest/index.html"
