$cs = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public static class Reg {
  [StructLayout(LayoutKind.Sequential)]
  public struct MBI { public IntPtr Base; public IntPtr AllocBase; public uint AllocProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint a, bool i, int pid);
  [DllImport("kernel32.dll", SetLastError=true)] static extern int VirtualQueryEx(IntPtr h, IntPtr addr, out MBI m, IntPtr len);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] b, IntPtr n, out IntPtr r);
  public static string Info(int pid, long addr) {
    IntPtr h = OpenProcess(0x410, false, pid);
    if (h == IntPtr.Zero) return "OPEN_FAIL " + Marshal.GetLastWin32Error();
    MBI m;
    if (VirtualQueryEx(h, (IntPtr)addr, out m, (IntPtr)Marshal.SizeOf(typeof(MBI))) == 0) return "QUERY_FAIL";
    return String.Format("base={0:X} alloc={1:X} size={2:X} state={3:X} prot={4:X} type={5:X}",
      m.Base.ToInt64(), m.AllocBase.ToInt64(), m.RegionSize.ToInt64(), m.State, m.Protect, m.Type);
  }
  public static string Dump(int pid, long addr, string outBin, string outMap, long maxBytes) {
    IntPtr h = OpenProcess(0x410, false, pid);
    if (h == IntPtr.Zero) return "OPEN_FAIL";
    MBI m;
    if (VirtualQueryEx(h, (IntPtr)addr, out m, (IntPtr)Marshal.SizeOf(typeof(MBI))) == 0) return "QUERY_FAIL";
    long b = m.Base.ToInt64(), sz = m.RegionSize.ToInt64();
    if (sz > maxBytes) sz = maxBytes;
    var buf = new byte[1 << 20];
    using (var fs = new FileStream(outBin, FileMode.Create, FileAccess.Write))
    using (var mp = new StreamWriter(outMap)) {
      for (long o = 0; o < sz; o += buf.Length) {
        int len = (int)Math.Min(buf.Length, sz - o);
        IntPtr read;
        if (!ReadProcessMemory(h, (IntPtr)(b + o), buf, (IntPtr)len, out read)) break;
        fs.Write(buf, 0, len);
        mp.WriteLine((b + o).ToString("X") + " " + len);
      }
    }
    return "region=" + sz;
  }
}
"@
Add-Type -TypeDefinition $cs -Language CSharp
$mode=$args[0]
if ($mode -eq 'info') { [Reg]::Info([int]$args[1],[long]$args[2]) }
else { [Reg]::Dump([int]$args[1],[long]$args[2],$args[3],$args[4],[long]$args[5]) }
