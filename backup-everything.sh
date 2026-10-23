#!/usr/bin/env bash
set -a

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
	rsync "${RSYNC_OPTS[@]}" \
		--exclude="Slack/" \
		--exclude="HEY/" \
		--exclude="Code - OSS/" \
		--exclude="chromium/" \
		--exclude="go/telemetry/" \
		--exclude="chrom.*flags.conf" \
		--exclude="electron.*flags.conf" \
		--exclude="microsoft.*flags.conf" \
		--exclude="youtube.*flags.conf" \
		--exclude="spotify/" \
		--exclude="discord/" \
		--exclude="Signal/" \
		--exclude="Todoist/" \
		--exclude="zsh/.zcompdump*" \
		"${SRC_CONFIG}" "${1}dotconfig/"

	rsync "${RSYNC_OPTS[@]}" "${SRC_VAULTS}" "${1}vaults/"
	rsync "${RSYNC_OPTS[@]}" "${SRC_TODOS}" "${1}todos/"
}

sync "${TGT_DROPBOX}"
sync "${TGT_SYNCTHING}"
sync "${TGT_SEAGATE_DRIVE}"

# .local/share
# SRC_SHARE="${HOME}/.local/share/"
# TGT_SHARE="${HOME}/Dropbox/backups/dotlocal-share/"

dotssh() (
	cd "$HOME" || exit
	tar --numeric-owner --xattrs --acls -czf .ssh-backup.tar.gz .ssh
	gpg -e -r beck@j38.uk -o ".dotssh.tar.gz.gpg" .ssh-backup.tar.gz

  rsync "${RSYNC_OPTS[@]}" .dotssh.tar.gz.gpg "${TGT_SEAGATE_DRIVE}/backup_ssh_keys/dotssh.tar.gz.gpg"
  rsync "${RSYNC_OPTS[@]}" .dotssh.tar.gz.gpg "${TGT_SYNCTHING}/backup_ssh_keys/dotssh.tar.gz.gpg"
	rm .dotssh.tar.gz.gpg
	rm .ssh-backup.tar.gz
)
dotssh
