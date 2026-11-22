#!/usr/bin/env bash
set -euo pipefail

# usage: ./render_final.sh <take.mp4> <subs.ass> <out.mp4> [cta_start=13] [main_len=30] [cta_len=15]
# take: vertical 9:16 30fps clip with the full spoken monologue
if [ $# -lt 3 ]; then
  echo "usage: $0 <take.mp4> <subs.ass> <out.mp4> [cta_start=13] [main_len=30] [cta_len=15]" >&2
  exit 1
fi

TAKE="$1"
SUBS="$2"
OUT="$3"
CTA_START="${4:-13}"
MAIN_LEN="${5:-30}"
CTA_LEN="${6:-15}"
CTA_END=$((CTA_START + CTA_LEN))

ffmpeg -y -i "$TAKE" -filter_complex "
[0:v]trim=0:${MAIN_LEN},setpts=PTS-STARTPTS,setsar=1,format=yuv420p[v1];
[0:v]trim=${CTA_START}:${CTA_END},setpts=PTS-STARTPTS,zoompan=z='min(zoom+0.0005,1.15)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=${CTA_LEN},setpts=PTS-STARTPTS,setsar=1,format=yuv420p[v2];
[v1][v2]concat=n=2:v=1:a=0,format=yuv420p,ass=${SUBS}[vout];
[0:a]atrim=0:${MAIN_LEN},asetpts=PTS-STARTPTS[a1];
[0:a]atrim=${CTA_START}:${CTA_END},asetpts=PTS-STARTPTS,volume=0.22,lowpass=f=800[a2];
[a1][a2]concat=n=2:v=0:a=1[aout]" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart "$OUT"

ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_type,codec_name -of compact=p=0 "$OUT"
