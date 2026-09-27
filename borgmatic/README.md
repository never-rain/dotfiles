# Borgmatic backup

The user timer runs `borgmatic create --stats` every Sunday at 18:00 local time.
`Persistent=true` catches up missed runs when the user timer starts again,
normally on login after boot. It does not wake a powered-off computer.

After stowing this package, enable the timer:

```sh
systemctl --user daemon-reload
systemctl --user enable --now borgmatic-backup.timer
```

The service sends a desktop notification through `notify-send` (handled by
swaync) on success or failure. A running desktop notification service is
required. The notification helper is invoked with `/bin/sh`.
SSH uses batch mode, so authentication must work without prompting in the
user service environment. The repository passphrase is read through the
configured `encryption_passcommand`; keep the secret outside this repository.

```sh
systemctl --user list-timers borgmatic-backup.timer
journalctl --user -u borgmatic-backup.service -n 80
# Run a backup with the same service and notification manually:
systemctl --user start borgmatic-backup.service
```

The timer creates backups only; it does not prune existing archives.
