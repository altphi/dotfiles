#!/usr/bin/env bash
set -euo pipefail

all_sessions=0

case "${1:-}" in
  "")
    ;;
  --all)
    all_sessions=1
    ;;
  *)
    printf 'Usage: %s [--all]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

window_args=()
window_format=$'#{?#{@window_mru},#{@window_mru},#{window_activity}}\t#{window_id}\t#{session_name}\t#{window_index}\t#{window_name}\t#{window_panes}\t#{P:#{pane_current_command} }\t#{s|^#{HOME}$|~|;s|^#{HOME}/|~/|:pane_current_path}'

if ((all_sessions)); then
  window_args=(-a)
fi

selected="$(
  tmux list-windows "${window_args[@]}" -F "$window_format" |
    sort -t $'\t' -k1,1rn |
    awk -F '\t' '
      BEGIN { OFS = FS }
      {
        commands = $7
        sub(/[[:space:]]+$/, "", commands)
        gsub(/[[:space:]]+/, ",", commands)
        $7 = commands
        rows[NR] = $0
        window_label = $4 ":" $5
        session_width = length($3) > session_width ? length($3) : session_width
        window_width = length(window_label) > window_width ? length(window_label) : window_width
        panes_width = length($6) > panes_width ? length($6) : panes_width
        command_width = length($7) > command_width ? length($7) : command_width
        path_width = length($8) > path_width ? length($8) : path_width
      }
      END {
        for (i = 1; i <= NR; i++) {
          split(rows[i], fields, FS)
          window_label = fields[4] ":" fields[5]
          pane_label = fields[6] " pane" (fields[6] == 1 ? "" : "s")
          printf "%s\t%-*s  %-*s  %*s  %-*s  %*s\n",
            fields[2],
            session_width, fields[3],
            window_width, window_label,
            panes_width + 6, pane_label,
            command_width, fields[7],
            path_width, fields[8]
        }
      }
    ' |
    fzf \
      -e \
      --delimiter=$'\t' \
      --with-nth 2 \
      --no-sort \
      --reverse \
      --cycle \
      --bind='enter:accept-or-print-query,tab:down,btab:up' \
      --preview='tmux capture-pane -p -t {1}' \
      --preview-window='right:60%,nowrap,follow'
)" || exit 0

[ -z "$selected" ] && exit 0

window_id="$(awk -F '\t' '{print $1}' <<< "$selected")"

if ! tmux list-windows -a -F '#{window_id}' | grep -qxF "$window_id"; then
  win_name_prompt="$selected"
  start_dir="$HOME"
  [ -d "$HOME/code/$win_name_prompt" ] && start_dir="$HOME/code/$win_name_prompt"
  [ -d "/srv/code/$win_name_prompt" ] && start_dir="/srv/code/$win_name_prompt"

  if tmux has-session -t "=$win_name_prompt" 2>/dev/null; then
    tmux switch-client -t "=$win_name_prompt"
  else
    tmux new-window -c "$start_dir" -n "$win_name_prompt"
  fi
elif ((all_sessions)); then
  tmux switch-client -t "$window_id"
else
  tmux select-window -t "$window_id"
fi
