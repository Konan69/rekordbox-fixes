# Install the waveform patch

The patch only takes effect when you replace the `rekordbox.exe` in your own rekordbox install with the patched copy. The repository does not ship rekordbox or any patched binary. Read [Limits](../README.md#limits) before you do this.

1. Close rekordbox.
2. In an administrator PowerShell, back up the original:

	```powershell
	cd "C:\Program Files\rekordbox\rekordbox 7.2.14"
	Copy-Item rekordbox.exe rekordbox.exe.before-zoom-patch
	```

3. In WSL, build the patched copy from the backup:

	```bash
	mkdir -p /mnt/c/Users/<you>/Downloads/rbpatch
	python3 patches/waveform-zoom/patch.py \
		"/mnt/c/Program Files/rekordbox/rekordbox 7.2.14/rekordbox.exe.before-zoom-patch" \
		/mnt/c/Users/<you>/Downloads/rbpatch/rekordbox.exe /mnt/c/Users/<you>/Downloads/rbpatch/manifest.json
	```

	The script must print `1d0e4e56...47f8 changed bytes: 239`. Any other result stops it with an `AssertionError` before it writes a file.

4. In the administrator PowerShell, replace the executable:

	```powershell
	Copy-Item "$env:USERPROFILE\Downloads\rbpatch\rekordbox.exe" rekordbox.exe -Force
	```

To restore the original, close rekordbox and copy the backup back:

```powershell
cd "C:\Program Files\rekordbox\rekordbox 7.2.14"
Copy-Item rekordbox.exe.before-zoom-patch rekordbox.exe -Force
(Get-FileHash rekordbox.exe).Hash   # F6359B6B3553E5F81E55444B28B7B56AA6F80F7BB7EB88F3C84D865D821AD5A9
```

If you have no backup, reinstall rekordbox 7.2.14. The patch does not change your library, settings or analysis files.
