# Configuration

`restore_analysis_state.py` reads environment variables. `recovery.config.example.sh` lists them. Copy it, edit it and `source` it before a run.

| Variable | Default | What it does |
| --- | --- | --- |
| `REKORDBOX_DB_KEY` | none (required) | The SQLCipher key of `master.db`. The script stops if it is unset. Keep it out of files you commit. |
| `REKORDBOX_ROOT` | `~/AppData/Roaming/Pioneer/rekordbox` | The directory that holds `master.db`, `master.backup2.db` and `share/`. With Windows Python the default is right. Under WSL, `~` is your Linux home, so set this to `/mnt/c/Users/<you>/AppData/Roaming/Pioneer/rekordbox`. |
| `REKORDBOX_RECOVERY` | `~/rekordbox-recovery` | Where `--apply` writes `<timestamp>/before.db`, `changes.json` and `analysis-file-evidence.json`. |
| `REKORDBOX_EXPECTED_CANDIDATES` | none (required for `--apply`) | The `verified_candidates` count from the dry run you reviewed. `--apply` stops if the count changed. |
| `REKORDBOX_POWERSHELL` | `powershell.exe` | The PowerShell used to check that the `rekordbox` process is closed. |

The PowerShell scripts take parameters instead:

| Parameter | Scripts | Default |
| --- | --- | --- |
| `-OutputDirectory` | `rbdump/watch.ps1`, `dump.ps1`, `screen.ps1`, `usb-rescan-admin.ps1`, `backup-before-update.ps1` | `%USERPROFILE%\rbdump` |
| `-HubPath` | `rbdump/usb-ports-read.ps1`, `usb-port-read.ps1` | none (required). The device path of a USB hub. |
| `-Ports` | `rbdump/usb-port-read.ps1` | none (required) |
| `RBSCAN_OUTPUT_DIR` (environment) | `rbscan/zoomtest.ps1` | `%USERPROFILE%\rbscan` |
