#!/usr/bin/env bash
set -euo pipefail

# usage: ./qc.sh <final.mp4> [ts:pos ...]   pos = top | bottom
# default checks: 2:top 15:bottom 41:bottom
FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "usage: $0 <final.mp4> [ts:pos ...]" >&2
  exit 1
fi
shift
SPECS=("$@")
if [ ${#SPECS[@]} -eq 0 ]; then
  SPECS=("2:top" "15:bottom" "41:bottom")
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "== probe"
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name,width,height \
  -of compact=p=0 "$FILE"

echo "== audio level (FAIL if mean < -30 dB or max < -20 dB)"
ffmpeg -v info -i "$FILE" -af volumedetect -f null - 2>&1 \
  | grep -E "mean_volume|max_volume" || true

echo "== ocr captions (empty text = caption NOT rendered)"
for spec in "${SPECS[@]}"; do
  t="${spec%%:*}"
  pos="${spec##*:}"
  if [ "$pos" = "top" ]; then
    crop="crop=1080:400:0:120"
  else
    crop="crop=1080:460:0:1330"
  fi
  ffmpeg -y -v error -ss "$t" -i "$FILE" -frames:v 1 -vf "$crop" "$TMPDIR/f.png"
  text=$(tesseract "$TMPDIR/f.png" - -l eng --psm 6 2>/dev/null | tr '\n' ' ')
  echo "t=${t}s [$pos]: ${text:-<empty>}"
done
