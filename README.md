# rekordbox-fixes

Why rekordbox freezes when a DDJ-FLX4 reconnects, and what to do about it.

rekordbox 7.2.14 went "Not Responding" every time my DDJ-FLX4 connected or disconnected. A minidump taken during the hang shows why: on every `WM_DEVICECHANGE`, rekordbox sends a synchronous HTTP request from its UI thread and waits for it, and rekordbox.com took 5.5 to 6.6 s to answer. This repo has the scripts that found it, plus a `master.db` analysis-state repair, window-style tools and an experimental waveform zoom-out patch. Full write-up: [rbdump/FINDINGS.md](rbdump/FINDINGS.md).

![A terminal runs cdb on a rekordbox hang dump. The UI thread's stack shows user32!__fnINDEVICECHANGE calling into WinINet's synchronous-call-on-UI-thread wait.](docs/media/hero.gif)

## Install

Windows 10 or 11 with PowerShell 5.1, rekordbox 7.2.14 x64, and WinDbg (`winget install Microsoft.WinDbg`) to read dumps. Python 3.12 for the repair and the patch; GNU binutils for the patch.

```bash
git clone <this-repo-url> rekordbox-fixes && cd rekordbox-fixes
python3 -m pip install -r requirements.txt   # sqlcipher3, for the analysis-state repair
```

Run the `.ps1` scripts with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>`.

## Use

Catch the freeze on your machine and read the UI thread:

```powershell
.\rbdump\watch.ps1                      # waits up to 120 min; on a hang writes two dumps to %USERPROFILE%\rbdump
# unplug the controller and plug it back in
cd $env:USERPROFILE\rbdump
$env:_NT_SYMBOL_PATH = "srv*$env:TEMP\sym*https://msdl.microsoft.com/download/symbols"
cdbX64.exe -z hang-034012-1.dmp -c "~0s; kc 30; q"
```

On my machine (the 18 unsymbolized `rekordbox` frames folded into one line):

```text
Call Site
ntdll!NtWaitForSingleObject
KERNELBASE!WaitForSingleObjectEx
wininet!CPendingSyncCall::HandlePendingSync_AppHangIsAppBugForCallingWinInetSyncOnUIThread
wininet!HttpWrapSendRequest
wininet!HttpEndRequestW
rekordbox
user32!UserCallWinProcCheckWow
user32!DispatchClientMessage
user32!__fnINDEVICECHANGE
ntdll!KiUserCallbackDispatcherContinue
win32u!NtUserGetMessage
user32!GetMessageW
```

The rest:

```powershell
.\rbdump\network-probe.ps1             # time the same WinINet request with and without proxy settings
.\rbdump\device-probe.ps1              # trigger the freeze on purpose; never during a set
.\rekordbox-borderless.ps1               # maximize without caption or frame; rekordbox-restore.ps1 undoes it
```

```bash
python3 restore_analysis_state.py         # dry run: tracks whose analysis flag regressed 105 -> 104
python3 patches/waveform-zoom/patch.py <original rekordbox.exe> <out.exe> <manifest.json>   # 7 -> 11 zoom-out levels
```

The repair changes nothing without `--apply`, verifies every analysis file against the backup's MD5s first, and rolls back unless every other table hashes the same. The patch only accepts the 7.2.14 executable by SHA-256, never writes to its input, and checks its own output hash.

Every script and how each part works: [docs/internals.md](docs/internals.md). Installing and undoing the patch: [docs/waveform-patch.md](docs/waveform-patch.md). Variables and parameters: [docs/configuration.md](docs/configuration.md).

## Limits

- The freeze is not fixed. The HTTP call is inside rekordbox. These scripts show the cause and help you find why the controller drops off USB.
- Every script targets rekordbox 7.2.14 on Windows and was tested on one machine with one DDJ-FLX4. Other versions are not confirmed.
- `device-probe.ps1` and `window-probe.ps1` freeze a running rekordbox for as long as the HTTP request takes. Do not run them during a set.
- The waveform patch is experimental. Whether the waveform draws correctly at every new zoom level is not confirmed. The patch also leaves untested the normal-mode caller that uses the alternate index and other wide-range views.
- The patched `rekordbox.exe` no longer matches its Authenticode signature, and its PE checksum is unchanged. Windows security tools and the rekordbox updater may treat it differently from the signed file. That behavior is not confirmed.
- The detours in `stubs.s` have no unwind metadata. They make no calls and use no stack.
- A rekordbox update replaces `rekordbox.exe`, and `patch.py` refuses any other build.
- Changing the rekordbox executable may be against its license agreement. Read the agreement before you install the patch.
- `restore_analysis_state.py` was not run against a library for this README. It handles only the 105 to 104 change of `Analysed`, and it needs `master.backup2.db` from before the change.

## License

MIT. Not affiliated with AlphaTheta or Pioneer DJ. No rekordbox binary, patched or not, is in this repo.
