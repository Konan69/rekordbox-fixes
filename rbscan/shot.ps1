Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$pid_ = [int]$args[0]
$out = $args[1]
$p = Get-Process -Id $pid_
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class R {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R_,B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
"@
$r = New-Object R+RECT
[R]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$w = $r.R_ - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"$w x $h"
