#!/usr/bin/env bash
# switch tmux panes by process name with fuzzel, create new session if none found

client=${1:-}

switch_client() {
    if [ -n "$client" ]; then
        tmux switch-client -c "$client" -t "$1"
    else
        tmux switch-client -t "$1"
    fi
}

bump_pane_mru() {
    tmux set -pF -t "$1" @pane_mru '#{e|+:#{@pane_mru_seq},1}'
    tmux set -gF @pane_mru_seq '#{e|+:#{@pane_mru_seq},1}'
}

selection=$(
  tmux list-panes -a -F '#{?#{@pane_mru},#{@pane_mru},0} #{pane_id} #S:#W:#{pane_current_command}' |
        sort -k1,1rn |
        awk '{
            pane_id = $2
            $1 = ""
            $2 = ""
            sub(/^  */, "")
            print pane_id "\t" $0
        }' |
        fuzzel --dmenu --no-sort --with-nth=2 --accept-nth=1 --match-nth=2
)

[ -z "$selection" ] && exit 0

target=$selection

if tmux list-panes -a -F '#{pane_id}' | grep -qxF "$target"; then
    switch_client "$target" && bump_pane_mru "$target"
else
    session="$selection"
    start_dir="$HOME"
    [ -d "$HOME/code/$session" ] && start_dir="$HOME/code/$session"
    [ -d "/srv/code/$session" ] && start_dir="/srv/code/$session"
    tmux new-session -d -s "$session" -c "$start_dir" && switch_client "=$session"
fi
