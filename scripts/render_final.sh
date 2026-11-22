#!/usr/bin/env bash
set -euo pipefail

# usage: ./render_final.sh <take.mp4> <subs.ass> <out.mp4> <cta_segments> [main_len=30]
# take: vertical 9:16 30fps clip with the full spoken monologue
# cta_segments: comma-separated start:len pairs, e.g. "11.2:5,19.5:5,25:5"
#               each segment gets a slow zoom and ducked audio as CTA b-roll
if [ $# -lt 4 ]; then
  echo "usage: $0 <take.mp4> <subs.ass> <out.mp4> <cta_segments> [main_len=30]" >&2
  echo "example: $0 take.mp4 subs.ass out.mp4 '11.2:5,19.5:5,25:5' 30" >&2
  exit 1
fi

TAKE="$1"
SUBS="$2"
OUT="$3"
CTA_SEGMENTS="$4"
MAIN_LEN="${5:-30}"

IFS=',' read -ra SEGS <<< "$CTA_SEGMENTS"
V=""
A=""
CONCAT_V="[v1]"
CONCAT_A="[a1]"

for i in "${!SEGS[@]}"; do
  s="${SEGS[$i]%%:*}"
  l="${SEGS[$i]##*:}"
  e=$(awk "BEGIN{print $s+$l}")
  idx=$((i + 2))
  V+="[0:v]trim=${s}:${e},setpts=PTS-STARTPTS,zoompan=z='min(zoom+0.0005,1.15)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=${l},setpts=PTS-STARTPTS,setsar=1,format=yuv420p[v${idx}];"
  A+="[0:a]atrim=${s}:${e},asetpts=PTS-STARTPTS,volume=0.22,lowpass=f=800[a${idx}];"
  CONCAT_V+="[v${idx}]"
  CONCAT_A+="[a${idx}]"
done

N=$(( ${#SEGS[@]} + 1 ))

ffmpeg -y -i "$TAKE" -filter_complex "
[0:v]trim=0:${MAIN_LEN},setpts=PTS-STARTPTS,setsar=1,format=yuv420p[v1];
[0:a]atrim=0:${MAIN_LEN},asetpts=PTS-STARTPTS[a1];
${V}${A}
${CONCAT_V}concat=n=${N}:v=1:a=0,format=yuv420p,ass=${SUBS}[vout];
${CONCAT_A}concat=n=${N}:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart "$OUT"

ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name -of compact=p=0 "$OUT"
