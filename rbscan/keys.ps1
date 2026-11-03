$cs = @"
using System;
using System.Runtime.InteropServices;
public static class Win {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
}
"@
Add-Type -TypeDefinition $cs
$pid_ = [int]$args[0]
$vk = [byte]$args[1]
$n = [int]$args[2]
$p = Get-Process -Id $pid_
$h = $p.MainWindowHandle
[Win]::ShowWindow($h, 9) | Out-Null
[Win]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
$fg = [Win]::GetForegroundWindow()
$fpid = 0
[Win]::GetWindowThreadProcessId($fg, [ref]$fpid) | Out-Null
if ($fpid -ne $pid_) {
    "ABORT foreground_pid=$fpid wanted=$pid_ (window not focused; nothing sent)"
    exit 2
}
for ($i = 0; $i -lt $n; $i++) {
    [Win]::keybd_event($vk, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [Win]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 500
"sent=$n vk=$vk to pid=$fpid"
