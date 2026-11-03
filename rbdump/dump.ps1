param([string]$OutputDirectory = (Join-Path $env:USERPROFILE "rbdump"))
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$p = Get-Process rekordbox -EA Stop | select -First 1
"pid=$($p.Id) responding=$($p.Responding) MB=$([int]($p.WS/1MB))"
Add-Type @"
using System; using System.Runtime.InteropServices;
public class D { [DllImport("dbghelp.dll", SetLastError=true)] public static extern bool MiniDumpWriteDump(IntPtr h, int pid, IntPtr f, int type, IntPtr e, IntPtr u, IntPtr c); }
"@
$out = (Join-Path $OutputDirectory "rb-$(Get-Date -f HHmmss).dmp")
$fs = [IO.File]::Create($out)
# Normal | WithHandleData | WithUnloadedModules | WithThreadInfo | WithProcessThreadData
$ok = [D]::MiniDumpWriteDump($p.Handle, $p.Id, $fs.SafeFileHandle.DangerousGetHandle(), 0x1124, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$fs.Close(); "dump=$ok $out $((Get-Item $out).Length)"
