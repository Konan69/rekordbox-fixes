$src = @"
using System;
using System.Runtime.InteropServices;
public class M {
  [StructLayout(LayoutKind.Sequential)]
  public struct MEMORY_BASIC_INFORMATION {
    public IntPtr BaseAddress;
    public IntPtr AllocationBase;
    public uint AllocationProtect;
    public IntPtr RegionSize;
    public uint State;
    public uint Protect;
    public uint Type;
  }
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern int VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
  [DllImport("kernel32.dll")]
  public static extern bool CloseHandle(IntPtr h);
}
"@
Add-Type -TypeDefinition $src

$pid_ = [int]$args[0]
$h = [M]::OpenProcess(0x410, $false, $pid_)
if ($h -eq [IntPtr]::Zero) { "OPEN_FAIL $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 1 }
$addr = [IntPtr]::Zero
$total = 0
$cnt = 0
$sz = [Runtime.InteropServices.Marshal]::SizeOf([type][M+MEMORY_BASIC_INFORMATION])
while ($true) {
  $mbi = New-Object M+MEMORY_BASIC_INFORMATION
  $r = [M]::VirtualQueryEx($h, $addr, [ref]$mbi, [IntPtr]$sz)
  if ($r -eq 0) { break }
  $prot = $mbi.Protect -band 0xFF
  if ($mbi.State -eq 0x1000 -and $mbi.Type -eq 0x20000 -and (($mbi.Protect -band 0x100) -eq 0) -and ($prot -eq 4 -or $prot -eq 0x40)) {
    $total += [int64]$mbi.RegionSize
    $cnt++
  }
  $addr = [IntPtr]([int64]$addr + [int64]$mbi.RegionSize)
  if ([int64]$addr -gt 0x7FFFFFFF0000) { break }
}
[M]::CloseHandle($h) | Out-Null
"regions=$cnt mb=$([int]($total/1MB))"
