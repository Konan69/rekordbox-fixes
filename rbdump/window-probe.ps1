Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RbWindows {
 public delegate bool EnumProc(IntPtr hwnd,IntPtr lparam);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr w,out uint pid);
 [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p,IntPtr a,string c,string n);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint f,uint t,out IntPtr result);
}
"@
$p=Get-Process rekordbox -ErrorAction Stop | Select-Object -First 1
$script:windows=New-Object 'System.Collections.Generic.List[IntPtr]'
$script:target=$p.Id
$cb=[RbWindows+EnumProc]{param($w,$l) $wpid=0; [void][RbWindows]::GetWindowThreadProcessId($w,[ref]$wpid); if($wpid -eq $script:target){$script:windows.Add($w)}; return $true}
[void][RbWindows]::EnumWindows($cb,[IntPtr]::Zero)
$w=[IntPtr]::Zero
while($true){$w=[RbWindows]::FindWindowEx([IntPtr](-3),$w,$null,$null); if($w -eq [IntPtr]::Zero){break}; $wpid=0;[void][RbWindows]::GetWindowThreadProcessId($w,[ref]$wpid); if($wpid -eq $p.Id){$script:windows.Add($w)}}
'windows='+$script:windows.Count
foreach($w in $script:windows){[void][RbWindows]::PostMessage($w,0x219,[IntPtr]7,[IntPtr]::Zero)}
$sw=[Diagnostics.Stopwatch]::StartNew()
$miss=0
while($sw.Elapsed.TotalSeconds -lt 20){$p.Refresh();$result=[IntPtr]::Zero;$r=[RbWindows]::SendMessageTimeout($p.MainWindowHandle,0,[IntPtr]::Zero,[IntPtr]::Zero,2,250,[ref]$result);if($r -eq [IntPtr]::Zero){$miss++;('{0:F2} stalled hwnd={1} err={2}' -f $sw.Elapsed.TotalSeconds,$p.MainWindowHandle,[Runtime.InteropServices.Marshal]::GetLastWin32Error())};Start-Sleep -Milliseconds 200}
'probe-stalled-samples='+$miss
