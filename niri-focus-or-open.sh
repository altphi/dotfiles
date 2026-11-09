#!/usr/bin/env bash

if [[ "$#" -ne 1 ]]; then
  echo "Error: No app_id provided."
  echo "Usage: $0 app_id"
  exit 1
fi

# App ID → launch command
declare -A apps=(
  ["chromium"]="chromium"
  ["zen"]="zen-beta"
  ["Slack"]="slack"
  ["signal"]="signal-desktop"
  ["spotify"]="spotify"
  ["Fastmail"]="fastmail"
  ["org.pwmt.zathura"]="zathura"
  ["TablePlus"]="tableplus"
)

WINDOW_ENTRY=$(niri msg -j windows | jq -r '.[] | "\(.app_id),\(.id)"' | grep "${1}")

if [[ ! -z "$WINDOW_ENTRY" ]]; then
  echo "$WINDOW_ENTRY" | head -n 1 | cut -d, -f2 | xargs niri msg action focus-window --id
elif [[ -n "${apps[$1]+x}" ]]; then
  niri msg action spawn -- "${apps[$1]}"
else
  echo "Error: No window found and no launch command mapped for '$1'"
  exit 1
fi
