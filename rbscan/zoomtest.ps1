# RBSCAN_OUTPUT_DIR overrides the screenshot directory.
$OutputDirectory = if ($env:RBSCAN_OUTPUT_DIR) { $env:RBSCAN_OUTPUT_DIR } else { Join-Path $env:USERPROFILE "rbscan" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R_,B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@
$pid_ = [int]$args[0]; $vk = [byte]$args[1]; $n = [int]$args[2]; $tag = $args[3]
$p = Get-Process -Id $pid_
$h = $p.MainWindowHandle
[W2]::ShowWindow($h, 9) | Out-Null
[W2]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 600
$fpid = 0
[W2]::GetWindowThreadProcessId([W2]::GetForegroundWindow(), [ref]$fpid) | Out-Null
if ($fpid -ne $pid_) { "ABORT focus=$fpid"; exit 2 }
$r = New-Object W2+RECT
[W2]::GetWindowRect($h, [ref]$r) | Out-Null
function Shot($path) {
  $bmp = New-Object System.Drawing.Bitmap ($r.R_-$r.L), ($r.B-$r.T)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
Shot (Join-Path $OutputDirectory "pre_$tag.png")
for ($i=0; $i -lt $n; $i++) {
  [W2]::keybd_event($vk, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 30
  [W2]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 350
}
Start-Sleep -Milliseconds 500
Shot (Join-Path $OutputDirectory "post_$tag.png")
"ok $tag"
