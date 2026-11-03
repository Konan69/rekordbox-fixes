Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RbProbe {
[DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint f,uint t,out IntPtr result);
}
"@
$p=Get-Process rekordbox -ErrorAction Stop | Select-Object -First 1
$window=$p.MainWindowHandle
'pid='+$p.Id+' hwnd='+$window
$posted=[RbProbe]::PostMessage($window,0x219,[IntPtr]7,[IntPtr]::Zero)
'Posted DEVNODES_CHANGED='+$posted
$sw=[Diagnostics.Stopwatch]::StartNew()
while($sw.Elapsed.TotalSeconds -lt 35) {
 $result=[IntPtr]::Zero
 $t=[Diagnostics.Stopwatch]::StartNew()
 $r=[RbProbe]::SendMessageTimeout($window,0,[IntPtr]::Zero,[IntPtr]::Zero,2,300,[ref]$result)
 ('{0:F2} responsive={1} waitMs={2}' -f $sw.Elapsed.TotalSeconds,($r -ne [IntPtr]::Zero),$t.ElapsedMilliseconds)
 Start-Sleep -Milliseconds 250
}
