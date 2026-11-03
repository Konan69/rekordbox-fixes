Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern long GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern long SetWindowLong(IntPtr h, int i, long v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int ht, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
"@
$p = Get-Process rekordbox -ErrorAction Stop
$h = $p.MainWindowHandle
[Win]::ShowWindow($h, 3) | Out-Null          # maximize
$GWL_STYLE = -16
$WS_CAPTION = 0x00C00000; $WS_THICKFRAME = 0x00040000; $WS_MINIMIZEBOX = 0x20000; $WS_MAXIMIZEBOX = 0x10000; $WS_SYSMENU = 0x80000
$style = [Win]::GetWindowLong($h, $GWL_STYLE)
$style = $style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME -bor $WS_MINIMIZEBOX -bor $WS_MAXIMIZEBOX -bor $WS_SYSMENU))
[Win]::SetWindowLong($h, $GWL_STYLE, $style) | Out-Null
$s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
[Win]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, $s.Width, $s.Height, 0x0040) | Out-Null
Write-Output "borderless applied"
