# Backup actions

A bar button labeled `job`. Click opens a terminal running `menu.sh`.

The menu needs a YAML file in `~/.config/borgmatic/` and asks before it writes anything. Without a terminal, set `BACKUP_ACTION` and `BACKUP_ASSUME_YES=1`.

| Action | What it runs |
| --- | --- |
| Backup now | `systemctl --user start omarchy-backup.service` when that unit is loaded. Otherwise `borgmatic create --verbosity 1`. Refuses when a backup is already running |
| List archives | `borgmatic repo-list` |
| Restore | `borgmatic extract --archive latest --path <relative> --destination <dir>`. The default directory is `~/Restores/<timestamp>/`. A destination that already has files is refused. `/` and the home directory are refused |
| Install the schedule | Copies `units/omarchy-backup.service` and `units/omarchy-backup.timer` into `~/.config/systemd/user/`, then `systemctl --user enable --now omarchy-backup.timer`. `BACKUP_CALENDAR` is `daily`, `6h`, or `weekly` |

The script does not prune, delete, or compact archives. The service runs `borgmatic create` only.

`BACKUP_SYSTEMCTL` and `BACKUP_BORGMATIC` replace those commands in tests.
