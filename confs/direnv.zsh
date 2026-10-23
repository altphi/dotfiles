# Source .envrc.zsh only when the allowed .envrc exports a literal
# DIRENV_ZSH_SHA256 of that file. A command substitution in .envrc would
# accept edits without a new `direnv allow`.
typeset -g _DIRENV_ZSH_LOADED=
typeset -g _DIRENV_ZSH_WARNED=
typeset -ga _DIRENV_ZSH_FUNCS

_direnv_zsh_warn() {
  emulate -L zsh
  local key=$1
  shift
  [[ $_DIRENV_ZSH_WARNED == "$key" ]] && return
  _DIRENV_ZSH_WARNED=$key
  print -ru2 -- "direnv zsh: $*"
}

_direnv_zsh_drop_funcs() {
  emulate -L zsh
  local fn
  for fn in "${_DIRENV_ZSH_FUNCS[@]}"; do
    unfunction -- "$fn" 2>/dev/null
  done
  _DIRENV_ZSH_FUNCS=()
}

_direnv_zsh_unload() {
  emulate -L zsh
  [[ -n $_DIRENV_ZSH_LOADED ]] || return 0
  if (( ${_DIRENV_ZSH_FUNCS[(I)direnv_zsh_unload]} )); then
    direnv_zsh_unload
  fi
  _direnv_zsh_drop_funcs
  unset _DIRENV_ZSH_LOADED
}

_direnv_zsh_hook() {
  emulate -L zsh
  local f sum
  local -a before now

  if [[ -z ${DIRENV_FILE:-} ]]; then
    _direnv_zsh_unload
    _DIRENV_ZSH_WARNED=
    return
  fi

  f=${DIRENV_FILE:h}/.envrc.zsh
  if [[ ! -f $f ]]; then
    if [[ -n ${DIRENV_ZSH_SHA256:-} ]]; then
      _direnv_zsh_warn "missing:$f" "DIRENV_ZSH_SHA256 is set but $f is missing"
    fi
    _direnv_zsh_unload
    return
  fi
  if [[ -z ${DIRENV_ZSH_SHA256:-} ]]; then
    _direnv_zsh_warn "unstamped:$f" "$f is not stamped. Run: direnv_zsh_stamp && direnv allow"
    _direnv_zsh_unload
    return
  fi

  sum=$(sha256sum -- "$f") || return
  sum=${sum%% *}
  if [[ $sum != "$DIRENV_ZSH_SHA256" ]]; then
    _direnv_zsh_warn "mismatch:$f:$sum:$DIRENV_ZSH_SHA256" \
      "$f does not match DIRENV_ZSH_SHA256. Run: direnv_zsh_stamp && direnv allow"
    _direnv_zsh_unload
    return
  fi
  [[ $_DIRENV_ZSH_LOADED == "$f:$sum" ]] && return

  _direnv_zsh_unload
  before=(${(k)functions})
  if ! source "$f"; then
    now=(${(k)functions})
    _DIRENV_ZSH_FUNCS=(${now:|before})
    _direnv_zsh_drop_funcs
    _direnv_zsh_warn "source:$f:$sum" "failed to source $f"
    return
  fi
  now=(${(k)functions})
  _DIRENV_ZSH_FUNCS=(${now:|before})
  _DIRENV_ZSH_LOADED=$f:$sum
  _DIRENV_ZSH_WARNED=
}

direnv_zsh_stamp() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local envrc=${1:-${DIRENV_FILE:-.envrc}}
  local zshf=${envrc:h}/.envrc.zsh
  local sum line tmp

  [[ -f $zshf ]] || { print -ru2 -- "direnv_zsh_stamp: no $zshf"; return 1 }
  [[ -f $envrc ]] || { print -ru2 -- "direnv_zsh_stamp: no $envrc"; return 1 }
  sum=$(sha256sum -- "$zshf") || return 1
  sum=${sum%% *}
  [[ $sum == [0-9a-fA-F](#c64) ]] || { print -ru2 -- "direnv_zsh_stamp: bad checksum"; return 1 }
  line="export DIRENV_ZSH_SHA256=$sum"
  tmp=$(mktemp) || return 1
  if awk -v line="$line" '
    /^export DIRENV_ZSH_SHA256=/ {
      if (!done) print line
      done = 1
      next
    }
    { print }
    END { if (!done) print line }
  ' "$envrc" > "$tmp" && command mv -- "$tmp" "$envrc"; then
    print -r -- "Wrote to $envrc:"
    print -r -- "  $line"
    print -r -- "Next: direnv allow"
  else
    local status=$?
    command rm -f -- "$tmp"
    return $status
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _direnv_zsh_hook
add-zsh-hook chpwd _direnv_zsh_hook
