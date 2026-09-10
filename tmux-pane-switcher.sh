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

pane_scope=-s
pane_format=$'#{?#{@pane_mru},#{@pane_mru},0}\t#{pane_id}\t#{window_id}\t#{session_name}\t#{pane_current_command}\t#{s|^#{HOME}$|~|;s|^#{HOME}/|~/|:pane_current_path}'

if ((all_sessions)); then
  pane_scope=-a
fi

selected="$(
  tmux list-panes "$pane_scope" -F "$pane_format" |
    sort -t $'\t' -k1,1rn |
    awk -F '\t' '
      {
        rows[NR] = $0
        session_width = length($4) > session_width ? length($4) : session_width
        command_width = length($5) > command_width ? length($5) : command_width
        path_width = length($6) > path_width ? length($6) : path_width
      }
      END {
        for (i = 1; i <= NR; i++) {
          split(rows[i], fields, FS)
          printf "%s\t%s\t%-*s  %-*s  %*s\n",
            fields[2], fields[3],
            session_width, fields[4],
            command_width, fields[5],
            path_width, fields[6]
        }
      }
    ' |
    fzf \
      -e \
      --delimiter=$'\t' \
      --with-nth 3 \
      --no-sort \
      --reverse \
      --cycle \
      --bind='enter:accept-or-print-query,tab:down,btab:up' \
      --preview='tmux capture-pane -p -t {1}' \
      --preview-window='right:60%,nowrap,follow'
)" || exit 0

[ -z "$selected" ] && exit 0

pane_id="$(awk -F '\t' '{print $1}' <<< "$selected")"
window_id="$(awk -F '\t' '{print $2}' <<< "$selected")"

if ! tmux list-panes -a -F '#{pane_id}' | grep -qxF "$pane_id"; then
  session="$selected"

  if tmux has-session -t "=$session" 2>/dev/null; then
    tmux switch-client -t "=$session"
  else
    start_dir="$HOME"
    [ -d "$HOME/code/$session" ] && start_dir="$HOME/code/$session"
    tmux new-session -d -s "$session" -c "$start_dir" && tmux switch-client -t "=$session"
  fi
elif ((all_sessions)); then
  tmux switch-client -t "$pane_id"
else
  tmux select-window -t "$window_id"
  tmux select-pane -t "$pane_id"
fi
