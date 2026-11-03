param([string]$OutputDirectory = (Join-Path $env:USERPROFILE "rbdump"))
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Add-Type @"
using System; using System.Runtime.InteropServices;
public class D { [DllImport("dbghelp.dll", SetLastError=true)] public static extern bool MiniDumpWriteDump(IntPtr h, int pid, IntPtr f, int type, IntPtr e, IntPtr u, IntPtr c); }
"@
$bad=0; $end=(Get-Date).AddMinutes(120)
while ((Get-Date) -lt $end) {
  $p = Get-Process rekordbox -EA 0 | select -First 1
  if ($p) { $p.Refresh(); if (-not $p.Responding) { $bad++ } else { $bad=0 } }
  if ($bad -ge 4) {
    foreach ($i in 1..2) {
      $out = (Join-Path $OutputDirectory "hang-$(Get-Date -f HHmmss)-$i.dmp"); $fs=[IO.File]::Create($out)
      $ok=[D]::MiniDumpWriteDump($p.Handle,$p.Id,$fs.SafeFileHandle.DangerousGetHandle(),0x1124,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero); $fs.Close()
      "HANG dumped $ok $out"; Start-Sleep 3
    }
    exit
  }
  Start-Sleep -Milliseconds 500
}
"no hang in 120 min"
