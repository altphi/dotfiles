#!/usr/bin/env bash
# switch tmux sessions by session name, create new if none found

session="$(
  tmux list-sessions -F "#{session_last_attached} #S" |
    sort -rn |
    cut -d' ' -f2- |
    fzf \
      -e \
      --delimiter=$'\t' \
      --no-sort \
      --reverse \
      --cycle \
      --bind='enter:accept-or-print-query,tab:down,btab:up' \
      --preview='tmux capture-pane -p -t {1}' \
      --preview-window='right:70%,nowrap,follow'
)"

[ -z "$session" ] && exit 0

if tmux has-session -t "=$session" 2>/dev/null; then
  tmux switch-client -t "=$session"
else
  start_dir="$HOME"
  [ -d "$HOME/code/$session" ] && start_dir="$HOME/code/$session"
  [ -d "/srv/code/$session" ] && start_dir="/srv/code/$session"
  tmux new-session -d -s "$session" -c "$start_dir" && tmux switch-client -t "=$session"
fi
