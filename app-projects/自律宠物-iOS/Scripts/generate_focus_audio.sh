#!/bin/zsh
set -euo pipefail

ffmpeg_bin="${FFMPEG_BIN:-$(command -v ffmpeg)}"
if [[ -z "${ffmpeg_bin}" ]]; then
  print -u2 "ffmpeg is required to generate the local focus tracks"
  exit 1
fi

project_root="${0:A:h:h}"
gentle_output="${project_root}/DisciplinedPet/Resources/Assets.xcassets/GentleFocus.dataset/gentle-focus.m4a"
ambient_output="${project_root}/DisciplinedPet/Resources/Assets.xcassets/QuietAmbient.dataset/quiet-ambient.m4a"

gentle_expression='0.026*((0.5+0.5*sin(2*PI*t/30))*(sin(2*PI*220*t)+0.58*sin(2*PI*275*t)+0.34*sin(2*PI*330*t))+(0.5-0.5*sin(2*PI*t/30))*(sin(2*PI*196*t)+0.58*sin(2*PI*245*t)+0.34*sin(2*PI*294*t)))*(0.82+0.18*sin(2*PI*t/12))'
ambient_expression='0.021*(sin(2*PI*110*t)+0.52*sin(2*PI*165*t)+0.28*sin(2*PI*220*t)+0.12*sin(2*PI*440*t))*(0.76+0.24*sin(2*PI*t/20))'

"${ffmpeg_bin}" -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc=${gentle_expression}:s=44100:d=60" \
  -c:a aac -b:a 96k -movflags +faststart "${gentle_output}"

"${ffmpeg_bin}" -hide_banner -loglevel error -y \
  -f lavfi -i "aevalsrc=${ambient_expression}:s=44100:d=60" \
  -c:a aac -b:a 96k -movflags +faststart "${ambient_output}"

print "Generated two deterministic 60-second focus loops."
