Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win2 {
  [DllImport("user32.dll")] public static extern long GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern long SetWindowLong(IntPtr h, int i, long v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int ht, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
"@
$p = Get-Process rekordbox -ErrorAction Stop
$h = $p.MainWindowHandle
$GWL_STYLE = -16
$WS_CAPTION = 0x00C00000; $WS_THICKFRAME = 0x00040000; $WS_MINIMIZEBOX = 0x20000; $WS_MAXIMIZEBOX = 0x10000; $WS_SYSMENU = 0x80000
$style = [Win2]::GetWindowLong($h, $GWL_STYLE)
$style = $style -bor $WS_CAPTION -bor $WS_THICKFRAME -bor $WS_MINIMIZEBOX -bor $WS_MAXIMIZEBOX -bor $WS_SYSMENU
[Win2]::SetWindowLong($h, $GWL_STYLE, $style) | Out-Null
[Win2]::ShowWindow($h, 3) | Out-Null   # re-maximize properly
[Win2]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, 0x0023) | Out-Null  # frame-changed + resize
Write-Output "restored"
