#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT

export HOME=$base/home
export XDG_CONFIG_HOME=$base/config
export BACKUP_CONFIG_DIR=$XDG_CONFIG_HOME/borgmatic
export BACKUP_UNIT_DIR=$XDG_CONFIG_HOME/systemd/user
export BACKUP_SKIP_PGREP=1
export BACKUP_ASSUME_YES=1
mkdir -p "$HOME" "$BACKUP_CONFIG_DIR" "$base/bin"

cat >"$base/bin/systemctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${BACKUP_SYSTEMCTL_LOG:?}"
if [[ $* == show\ omarchy-backup.service\ -p\ ActiveState* ]]; then
  if [[ ${BACKUP_SERVICE_ACTIVE:-inactive} == active ]]; then
    echo "ActiveState=active"
  else
    echo "ActiveState=inactive"
  fi
  exit 0
fi
if [[ $* == show\ omarchy-backup.service\ -p\ LoadState* ]]; then
  echo "LoadState=${BACKUP_SERVICE_LOAD:-loaded}"
  exit 0
fi
exit 0
EOF
chmod +x "$base/bin/systemctl"

cat >"$base/bin/borgmatic" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${BACKUP_BORGMATIC_LOG:?}"
exit 0
EOF
chmod +x "$base/bin/borgmatic"

export BACKUP_SYSTEMCTL=$base/bin/systemctl
export BACKUP_BORGMATIC=$base/bin/borgmatic
export BACKUP_SYSTEMCTL_LOG=$base/systemctl.log
export BACKUP_BORGMATIC_LOG=$base/borgmatic.log
: >"$BACKUP_SYSTEMCTL_LOG"
: >"$BACKUP_BORGMATIC_LOG"

set +e
out=$(BACKUP_ACTION=now "$root/menu.sh" 2>&1)
code=$?
set -e
[[ $code -ne 0 ]] || { echo "now without config should fail: $out"; exit 1; }
[[ ! -s $BACKUP_BORGMATIC_LOG ]] || { echo "now without config called borgmatic"; exit 1; }

printf 'source_directories:\n  - /home/you\n' >"$BACKUP_CONFIG_DIR/config.yaml"

BACKUP_SERVICE_LOAD=loaded BACKUP_ACTION=now "$root/menu.sh"
grep -qx 'start omarchy-backup.service' "$BACKUP_SYSTEMCTL_LOG"
[[ ! -s $BACKUP_BORGMATIC_LOG ]]

: >"$BACKUP_SYSTEMCTL_LOG"
BACKUP_SERVICE_LOAD=not-found BACKUP_ACTION=now "$root/menu.sh"
grep -qx 'create --verbosity 1' "$BACKUP_BORGMATIC_LOG"
grep -q 'start omarchy-backup.service' "$BACKUP_SYSTEMCTL_LOG" && { echo "missing unit was started"; exit 1; }

: >"$BACKUP_SYSTEMCTL_LOG"
: >"$BACKUP_BORGMATIC_LOG"
set +e
out=$(BACKUP_SERVICE_ACTIVE=active BACKUP_ACTION=now "$root/menu.sh" 2>&1)
code=$?
set -e
[[ $code -ne 0 ]] || { echo "active backup should refuse: $out"; exit 1; }
[[ ! -s $BACKUP_BORGMATIC_LOG ]]
grep -q 'start omarchy-backup.service' "$BACKUP_SYSTEMCTL_LOG" && { echo "active backup was started"; exit 1; }

: >"$BACKUP_BORGMATIC_LOG"
dest=$base/restore
mkdir -p "$dest"
BACKUP_ACTION=restore BACKUP_RESTORE_PATH=/home/you/Documents/notes.md BACKUP_DESTINATION=$dest "$root/menu.sh" >/dev/null
grep -qx 'extract --archive latest --path home/you/Documents/notes.md --destination '"$dest" "$BACKUP_BORGMATIC_LOG"

set +e
out=$(BACKUP_ACTION=restore BACKUP_RESTORE_PATH=/home/you/../../etc/passwd BACKUP_DESTINATION=$base/nope "$root/menu.sh" 2>&1)
code=$?
set -e
[[ $code -ne 0 ]] || { echo "dotdot path should fail: $out"; exit 1; }
[[ ! -d $base/nope ]]

mkdir -p "$dest/already"
echo kept >"$dest/already/file"
set +e
out=$(BACKUP_ACTION=restore BACKUP_RESTORE_PATH=home/you/notes.md BACKUP_DESTINATION=$dest "$root/menu.sh" 2>&1)
code=$?
set -e
[[ $code -ne 0 ]] || { echo "non-empty destination should fail: $out"; exit 1; }

: >"$BACKUP_SYSTEMCTL_LOG"
BACKUP_ACTION=schedule BACKUP_CALENDAR=6h "$root/menu.sh" >/dev/null
grep -Fxq 'OnCalendar=*-*-* 00/6:00:00' "$BACKUP_UNIT_DIR/omarchy-backup.timer"
grep -q 'OnCalendar=daily' "$BACKUP_UNIT_DIR/omarchy-backup.timer" && { echo "daily calendar leaked"; exit 1; }
grep -qx 'ExecStart=/usr/bin/borgmatic create --verbosity 1' "$BACKUP_UNIT_DIR/omarchy-backup.service"
grep -qx 'daemon-reload' "$BACKUP_SYSTEMCTL_LOG"
grep -qx 'enable --now omarchy-backup.timer' "$BACKUP_SYSTEMCTL_LOG"

set +e
out=$(BACKUP_ACTION=schedule BACKUP_CALENDAR=hourly "$root/menu.sh" 2>&1)
code=$?
set -e
[[ $code -ne 0 ]] || { echo "unknown calendar should fail: $out"; exit 1; }

echo "ok - backup actions"
