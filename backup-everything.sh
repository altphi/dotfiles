#!/usr/bin/env bash
set -a

# Top-level ~/.config directories to skip. Everything else is copied.
EXCLUDE=(
	Slack
	discord
	Signal
	chromium
  "Grok Bot"
)

IGNORE_SIZE=(
	REAPER
)

LARGE=$((100 * 1024 * 1024))

RSYNC_OPTS=(
-aP
--delete
--mkpath)

SRC_CONFIG="${HOME}/.config/"
SRC_VAULTS="${HOME}/vaults/"
SRC_TODOS="${HOME}/todos/"

TGT_DROPBOX="${HOME}/Dropbox/backups/"
TGT_SYNCTHING="${HOME}/syncedthings/backups/"
TGT_SEAGATE_DRIVE="/mnt/seagate-backup/backups/"

sync() {
	local -a filters=()
	local name
	for name in "${EXCLUDE[@]}"; do
		filters+=(--exclude="/${name}/")
	done

	rsync "${RSYNC_OPTS[@]}" \
		"${filters[@]}" \
		"${SRC_CONFIG}" "${1}dotconfig/"

	rsync "${RSYNC_OPTS[@]}" "${SRC_VAULTS}" "${1}vaults/"
	rsync "${RSYNC_OPTS[@]}" "${SRC_TODOS}" "${1}todos/"
}

report_large() (
	local -A skip=()
	local name entry base size
	local large_mb=$((LARGE / 1024 / 1024))
	for name in "${EXCLUDE[@]}" "${IGNORE_SIZE[@]}"; do
		skip["$name"]=1
	done

	local -a big=()
	shopt -s nullglob dotglob
	for entry in "${SRC_CONFIG}"*; do
		[[ -d "$entry" ]] || continue
		base=${entry##*/}
		[[ -n ${skip[$base]+x} ]] && continue
		size=$(du -sb "$entry" | awk '{print $1}')
		((size > LARGE)) || continue
		big+=("$(printf '%s\t%s' "$size" "$base")")
	done
	if ((${#big[@]} == 0)); then
		echo "backup-everything: no copied ~/.config folder over ${large_mb}MB outside IGNORE_SIZE" >&2
		exit 0
	fi

	echo "backup-everything: copied ~/.config folders over ${large_mb}MB and not in IGNORE_SIZE:" >&2
	printf '%s\n' "${big[@]}" | sort -nr | while IFS=$'\t' read -r size base; do
		printf '  %s/ %dM\n' "$base" $((size / 1024 / 1024)) >&2
	done
	exit 1
)

# The directory is still there when the disk is unplugged. --mkpath would
# then write the backup onto the root filesystem.
if mountpoint -q /mnt/seagate-backup; then
	SEAGATE=1
else
	SEAGATE=0
	echo "backup-everything: /mnt/seagate-backup is not mounted, skipping that copy" >&2
fi

sync "${TGT_DROPBOX}"
sync "${TGT_SYNCTHING}"
if ((SEAGATE)); then
	sync "${TGT_SEAGATE_DRIVE}"
fi

# TODO .local/share
# SRC_SHARE="${HOME}/.local/share/"
# TGT_SHARE="${HOME}/Dropbox/backups/dotlocal-share/"

dotssh() (
	cd "$HOME" || exit
	tar --numeric-owner --xattrs --acls -czf .ssh-backup.tar.gz .ssh
	gpg -e -r beck@j38.uk -o ".dotssh.tar.gz.gpg" .ssh-backup.tar.gz

	if ((SEAGATE)); then
		rsync "${RSYNC_OPTS[@]}" .dotssh.tar.gz.gpg "${TGT_SEAGATE_DRIVE}/backup_ssh_keys/dotssh.tar.gz.gpg"
	fi
	rsync "${RSYNC_OPTS[@]}" .dotssh.tar.gz.gpg "${TGT_SYNCTHING}/backup_ssh_keys/dotssh.tar.gz.gpg"
	rm .dotssh.tar.gz.gpg
	rm .ssh-backup.tar.gz
)
dotssh

report_large
