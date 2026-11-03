Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W4 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R_,B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@
$pid_ = [int]$args[0]; $out = $args[1]; $seq = $args[2]
$p = Get-Process -Id $pid_
$h = $p.MainWindowHandle
[W4]::ShowWindow($h, 9) | Out-Null
[W4]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 600
$fpid = 0
[W4]::GetWindowThreadProcessId([W4]::GetForegroundWindow(), [ref]$fpid) | Out-Null
if ($fpid -ne $pid_) { "ABORT focus=$fpid"; exit 2 }
# seq: pairs vk,count separated by comma e.g. "187:3"
foreach ($step in $seq.Split(',')) {
  $parts = $step.Split(':')
  $vk = [byte][int]$parts[0]; $n = [int]$parts[1]
  for ($i=0; $i -lt $n; $i++) {
    [W4]::keybd_event($vk, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [W4]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 300
  }
}
Start-Sleep -Milliseconds 700
$r = New-Object W4+RECT
[W4]::GetWindowRect($h, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.R_-$r.L), ($r.B-$r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"shot"
