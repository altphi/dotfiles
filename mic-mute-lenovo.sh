#!/usr/bin/env bash
# One switch for this ThinkPad's split audio:
#   PipeWire sources  = what apps hear (ACP digital mic, analog mic, Easy Effects)
#   ALSA Capture@card1 = analog path whose mute bit drives platform::micmute
set -euo pipefail

alsa_capture() {
  amixer -q -c 1 set Capture "$1"
}

pw_mute() {
  pactl list short sources | awk '$2 !~ /\.monitor$/ { print $1 }' | while read -r id; do
    pactl set-source-mute "$id" "$1"
  done
}

is_muted() {
  wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED
}

cmd=${1:-toggle}

if [[ "$cmd" == sync ]]; then
  if is_muted; then alsa_capture nocap; else alsa_capture cap; fi
  exit 0
fi

if [[ "$cmd" == mute ]] || { [[ "$cmd" == toggle ]] && ! is_muted; }; then
  pw_mute 1
  alsa_capture nocap
else
  pw_mute 0
  alsa_capture cap
fi
