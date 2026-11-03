Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win3 {
  [DllImport("user32.dll")] public static extern long GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern long SetWindowLong(IntPtr h, int i, long v);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int ht, uint f);
}
"@
$GWL_STYLE = -16
$CAPTION = 0x00C00000; $THICKFRAME = 0x00040000; $MINBOX = 0x20000; $MAXBOX = 0x10000; $SYSMENU = 0x80000
$hidden = $false
Write-Output "watcher running"
while ($true) {
  Start-Sleep -Milliseconds 200
  $p = Get-Process rekordbox -ErrorAction SilentlyContinue
  if (-not $p -or $p.MainWindowHandle -eq 0) { $hidden = $false; continue }
  $h = $p.MainWindowHandle
  $m = [System.Windows.Forms.Cursor]::Position
  $topStyle = [Win3]::GetWindowLong($h, $GWL_STYLE)
  if ($m.Y -le 2 -and $hidden) {
    # reveal: add caption back
    $s = $topStyle -bor $CAPTION -bor $THICKFRAME -bor $MINBOX -bor $MAXBOX -bor $SYSMENU
    [Win3]::SetWindowLong($h, $GWL_STYLE, $s) | Out-Null
    [Win3]::ShowWindow($h, 3) | Out-Null
    [Win3]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, 0x0023) | Out-Null
    $hidden = $false
  }
  elseif ($m.Y -gt 60 -and -not $hidden) {
    # hide again once mouse leaves the bar area
    $s = $topStyle -band (-bnot ($CAPTION -bor $THICKFRAME -bor $MINBOX -bor $MAXBOX -bor $SYSMENU))
    [Win3]::SetWindowLong($h, $GWL_STYLE, $s) | Out-Null
    [Win3]::ShowWindow($h, 3) | Out-Null
    [Win3]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, 0x0023) | Out-Null
    $hidden = $true
  }
}
