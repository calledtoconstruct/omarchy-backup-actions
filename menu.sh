#!/bin/bash

# Backup actions. Each write asks first, unless BACKUP_ASSUME_YES=1.
# Restore extracts into a new directory. This script does not prune or delete.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -n ${BACKUP_CONFIG_DIR:-} ]]; then
  config_dir=$BACKUP_CONFIG_DIR
else
  home=${HOME:-}
  config_home=${XDG_CONFIG_HOME:-${home:+$home/.config}}
  config_dir=${config_home:+$config_home/borgmatic}
fi

unit_dir=${BACKUP_UNIT_DIR:-${XDG_CONFIG_HOME:-${HOME:-}/.config}/systemd/user}

systemctl_user() {
  if [[ -n ${BACKUP_SYSTEMCTL:-} ]]; then
    "$BACKUP_SYSTEMCTL" "$@"
    return
  fi
  systemctl --user "$@"
}

borgmatic_cmd() {
  if [[ -n ${BACKUP_BORGMATIC:-} ]]; then
    "$BACKUP_BORGMATIC" "$@"
    return
  fi
  borgmatic "$@"
}

confirm() {
  local prompt=$1
  if [[ ${BACKUP_ASSUME_YES:-} == 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "Refusing without a terminal: $prompt" >&2
    return 1
  fi
  gum confirm "$prompt"
}

require_config() {
  if [[ -z ${config_dir:-} || ! -d $config_dir ]]; then
    echo "No borgmatic config directory. Copy ~/.config/omarchy-bundles/backup/config.yaml to ~/.config/borgmatic/config.yaml and edit it." >&2
    exit 1
  fi
  shopt -s nullglob
  local files=("$config_dir"/*.yaml "$config_dir"/*.yml)
  shopt -u nullglob
  if ((${#files[@]} == 0)); then
    echo "No YAML file in $config_dir. Copy ~/.config/omarchy-bundles/backup/config.yaml there and replace YOU and CHANGE_ME." >&2
    exit 1
  fi
}

already_running() {
  if [[ ${BACKUP_SKIP_PGREP:-} != 1 ]]; then
    if pgrep -x borgmatic >/dev/null 2>&1 || pgrep -x borg >/dev/null 2>&1; then
      return 0
    fi
  fi
  local show active
  show=$(systemctl_user show omarchy-backup.service -p ActiveState --no-pager 2>/dev/null || true)
  active=$(awk -F= '$1 == "ActiveState" { print substr($0, index($0, "=") + 1); exit }' <<<"$show")
  [[ $active == active || $active == activating ]]
}

action_now() {
  require_config
  if already_running; then
    echo "A backup is already running." >&2
    exit 1
  fi
  confirm "Start a backup now?"
  local show load
  show=$(systemctl_user show omarchy-backup.service -p LoadState --no-pager 2>/dev/null || true)
  load=$(awk -F= '$1 == "LoadState" { print substr($0, index($0, "=") + 1); exit }' <<<"$show")
  if [[ $load == loaded ]]; then
    systemctl_user start omarchy-backup.service
  else
    borgmatic_cmd create --verbosity 1
  fi
}

action_list() {
  require_config
  borgmatic_cmd repo-list
}

normalize_archive_path() {
  local p=$1
  while [[ $p == /* ]]; do
    p=${p#/}
  done
  if [[ -z $p || $p == "." || $p == ".." || $p == ../* || $p == */.. || $p == */../* ]]; then
    echo "Refusing path: ${1}" >&2
    return 1
  fi
  if [[ $p == *$'\n'* ]]; then
    echo "Refusing path with a newline." >&2
    return 1
  fi
  printf '%s\n' "$p"
}

normalize_archive_name() {
  local name=$1
  if [[ ! $name =~ ^[A-Za-z0-9._:+-]+$ || $name == "." || $name == ".." ]]; then
    echo "Refusing archive name: $name" >&2
    return 1
  fi
  printf '%s\n' "$name"
}

action_restore() {
  require_config
  local raw=${BACKUP_RESTORE_PATH:-}
  local archive=${BACKUP_ARCHIVE:-latest}
  local dest=${BACKUP_DESTINATION:-}
  if [[ -z $raw ]]; then
    if [[ ! -t 0 ]]; then
      echo "Set BACKUP_RESTORE_PATH." >&2
      exit 2
    fi
    raw=$(gum input --placeholder "/home/you/Documents/notes.md")
  fi
  archive=$(normalize_archive_name "$archive")
  local rel
  rel=$(normalize_archive_path "$raw")
  if [[ -z $dest ]]; then
    dest=${HOME:-}/Restores/$(date +%Y%m%d-%H%M%S)
  fi
  if [[ -z $dest || $dest == "/" || $dest == "${HOME:-}" ]]; then
    echo "Refusing destination: ${dest:-<empty>}" >&2
    exit 1
  fi
  mkdir -p -- "$dest"
  if [[ -n $(find "$dest" -mindepth 1 -print -quit) ]]; then
    echo "Destination already has files: $dest" >&2
    exit 1
  fi
  confirm "Extract $rel from $archive into $dest?"
  borgmatic_cmd extract --archive "$archive" --path "$rel" --destination "$dest"
  echo "$dest"
}

calendar_line() {
  case $1 in
    daily) printf '%s\n' 'OnCalendar=daily' ;;
    6h) printf '%s\n' 'OnCalendar=*-*-* 00/6:00:00' ;;
    weekly) printf '%s\n' 'OnCalendar=Sun *-*-* 03:00:00' ;;
    *)
      echo "Set BACKUP_CALENDAR to daily, 6h, or weekly." >&2
      return 1
      ;;
  esac
}

action_schedule() {
  require_config
  local calendar=${BACKUP_CALENDAR:-}
  if [[ -z $calendar ]]; then
    if [[ ${BACKUP_ASSUME_YES:-} == 1 || ! -t 0 ]]; then
      echo "Set BACKUP_CALENDAR to daily, 6h, or weekly." >&2
      exit 2
    fi
    calendar=$(gum choose daily 6h weekly)
  fi
  local line
  line=$(calendar_line "$calendar")
  confirm "Install omarchy-backup.timer with $line?"
  mkdir -p -- "$unit_dir"
  cp "$root/units/omarchy-backup.service" "$unit_dir/omarchy-backup.service"
  awk -v line="$line" '
    /^OnCalendar=/ { print line; next }
    { print }
  ' "$root/units/omarchy-backup.timer" >"$unit_dir/omarchy-backup.timer"
  systemctl_user daemon-reload
  systemctl_user enable --now omarchy-backup.timer
  echo "Enabled omarchy-backup.timer ($line)"
}

interactive() {
  local choice
  choice=$(gum choose "Backup now" "List archives" "Restore a file or folder" "Install the schedule" "Quit")
  case $choice in
    "Backup now") action_now ;;
    "List archives") action_list ;;
    "Restore a file or folder") action_restore ;;
    "Install the schedule") action_schedule ;;
    *) exit 0 ;;
  esac
}

case ${BACKUP_ACTION:-} in
  now) action_now ;;
  list) action_list ;;
  restore) action_restore ;;
  schedule) action_schedule ;;
  "")
    if [[ -t 0 ]]; then
      interactive
    else
      echo "Set BACKUP_ACTION to now, list, restore, or schedule." >&2
      exit 2
    fi
    ;;
  *)
    echo "Unknown BACKUP_ACTION: $BACKUP_ACTION" >&2
    exit 2
    ;;
esac
