# rekordbox freeze, 22 Oct 2026

Symptom: rekordbox 7.2.14 shows "Not Responding" (AppHangB1) whenever the DDJ-FLX4 connects or disconnects.
Hangs logged since 10 Sep: 5 closed by Windows, plus several transient ones.

## Root cause (from hang-034012-1.dmp, UI thread 0)
user32!__fnINDEVICECHANGE  -> rekordbox WM_DEVICECHANGE handler
  -> wininet!HttpEndRequestW -> HttpWrapSendRequest
  -> wininet!CPendingSyncCall::HandlePendingSync_AppHangIsAppBugForCallingWinInetSyncOnUIThread
  -> WaitForSingleObject
On each USB plug/unplug, rekordbox makes a synchronous HTTP request on its UI thread (a rekordbox bug).
The window freezes until the request returns. From this connection, rekordbox.com takes 5.5-6.6 s
(DNS 0.2 s, TLS 0.4 s, the rest is server time), so every reconnect freezes it for at least 5 s.

## Trigger: the FLX4 drops off USB on its own
- Plugged straight into the laptop's Intel USB 3.2 root hub (no external hub).
- USB selective suspend is already off on AC and DC.
- FLX4 is class compliant (no vendor driver exists); it runs on Windows class audio + Windows MIDI Services.
- Charger plug/unplug ("Power source change") happened at 02:52:28, one minute before the 02:53 hang.

## Changes made
- WasapiExclusive 1 -> 0 in rekordbox3.settings (backup: rekordbox3.settings.bak-2026-10-22). Running copy may overwrite it.
- rekordbox.exe set to the NVIDIA GPU (HKCU DirectX UserGpuPreferences).
- Installed WinDbg (winget Microsoft.WinDbg) to read the dumps.
