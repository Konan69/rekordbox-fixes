$cs = @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class Scan
{
    [StructLayout(LayoutKind.Sequential)]
    public struct MBI {
        public IntPtr Base;
        public IntPtr AllocBase;
        public uint AllocProtect;
        public IntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern int VirtualQueryEx(IntPtr h, IntPtr addr, out MBI m, IntPtr len);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);

    const int PAGE = 4096;

    static List<long[]> Regions(IntPtr h)
    {
        var list = new List<long[]>();
        long addr = 0;
        while (true)
        {
            MBI m;
            if (VirtualQueryEx(h, (IntPtr)addr, out m, (IntPtr)Marshal.SizeOf(typeof(MBI))) == 0) break;
            long size = m.RegionSize.ToInt64();
            uint prot = m.Protect & 0xFF;
            if (m.State == 0x1000 && m.Type == 0x20000 && (m.Protect & 0x100) == 0 && (prot == 4 || prot == 0x40))
                list.Add(new long[] { m.Base.ToInt64(), size });
            addr += size;
            if (addr > 0x7FFFFFFFFFFF) break;
        }
        return list;
    }

    static ulong Fnv(byte[] b, int off, int len)
    {
        ulong h = 14695981039346656037UL;
        for (int i = off; i < off + len; i++) { h ^= b[i]; h *= 1099511628211UL; }
        return h;
    }

    public static string Hash(int pid, string outPath)
    {
        IntPtr h = OpenProcess(0x410, false, pid);
        if (h == IntPtr.Zero) return "OPEN_FAIL " + Marshal.GetLastWin32Error();
        var regions = Regions(h);
        long total = 0;
        using (var sw = new StreamWriter(outPath))
        {
            var buf = new byte[PAGE];
            foreach (var r in regions)
            {
                long b = r[0], sz = r[1];
                for (long o = 0; o < sz; o += PAGE)
                {
                    int len = (int)Math.Min(PAGE, sz - o);
                    IntPtr read;
                    if (!ReadProcessMemory(h, (IntPtr)(b + o), buf, (IntPtr)len, out read)) { sw.WriteLine((b + o).ToString("X") + " F"); continue; }
                    sw.WriteLine((b + o).ToString("X") + " " + Fnv(buf, 0, len).ToString("X16"));
                    total++;
                }
            }
        }
        CloseHandle(h);
        return "pages=" + total;
    }

    public static string DumpSmall(int pid, string outBin, string outMap, long maxRegion)
    {
        IntPtr h = OpenProcess(0x410, false, pid);
        if (h == IntPtr.Zero) return "OPEN_FAIL";
        var regions = Regions(h);
        long total = 0;
        using (var fs = new FileStream(outBin, FileMode.Create, FileAccess.Write))
        using (var mp = new StreamWriter(outMap))
        {
            var buf = new byte[1 << 20];
            foreach (var r in regions)
            {
                long b = r[0], sz = r[1];
                if (sz > maxRegion) continue;
                for (long o = 0; o < sz; o += buf.Length)
                {
                    int len = (int)Math.Min(buf.Length, sz - o);
                    IntPtr read;
                    Array.Clear(buf, 0, len);
                    if (!ReadProcessMemory(h, (IntPtr)(b + o), buf, (IntPtr)len, out read)) continue;
                    fs.Write(buf, 0, len);
                    mp.WriteLine((b + o).ToString("X") + " " + len);
                    total += len;
                }
            }
        }
        CloseHandle(h);
        return "bytes=" + total;
    }


    public static string DumpChanged(int pid, string prevHash, string outBin, string outMap, string newHashOut)
    {
        IntPtr h = OpenProcess(0x410, false, pid);
        if (h == IntPtr.Zero) return "OPEN_FAIL " + Marshal.GetLastWin32Error();
        var prev = new System.Collections.Generic.Dictionary<long, ulong>();
        foreach (var line in File.ReadAllLines(prevHash))
        {
            var sp = line.Split(' ');
            if (sp.Length == 2 && sp[1] != "F") prev[Convert.ToInt64(sp[0], 16)] = Convert.ToUInt64(sp[1], 16);
        }
        var regions = Regions(h);
        long total = 0, npages = 0;
        using (var fs = new FileStream(outBin, FileMode.Create, FileAccess.Write))
        using (var mp = new StreamWriter(outMap))
        using (var nh = new StreamWriter(newHashOut))
        {
            var buf = new byte[PAGE];
            foreach (var r in regions)
            {
                long b = r[0], sz = r[1];
                for (long o = 0; o < sz; o += PAGE)
                {
                    int len = (int)Math.Min(PAGE, sz - o);
                    IntPtr read;
                    Array.Clear(buf, 0, PAGE);
                    if (!ReadProcessMemory(h, (IntPtr)(b + o), buf, (IntPtr)len, out read)) { nh.WriteLine((b + o).ToString("X") + " F"); continue; }
                    ulong hv = Fnv(buf, 0, len);
                    nh.WriteLine((b + o).ToString("X") + " " + hv.ToString("X16"));
                    ulong pv;
                    bool changed = !prev.TryGetValue(b + o, out pv) || pv != hv;
                    if (changed)
                    {
                        fs.Write(buf, 0, PAGE);
                        mp.WriteLine((b + o).ToString("X") + " " + PAGE);
                        npages++; total += PAGE;
                    }
                }
            }
        }
        CloseHandle(h);
        return "changed_pages=" + npages + " bytes=" + total;
    }

    public static string DumpPages(int pid, string pagesFile, string outBin, string outMap)
    {
        IntPtr h = OpenProcess(0x410, false, pid);
        if (h == IntPtr.Zero) return "OPEN_FAIL";
        var pages = File.ReadAllLines(pagesFile);
        using (var fs = new FileStream(outBin, FileMode.Create, FileAccess.Write))
        using (var mp = new StreamWriter(outMap))
        {
            var buf = new byte[PAGE];
            foreach (var line in pages)
            {
                string s = line.Trim();
                if (s.Length == 0) continue;
                long a = Convert.ToInt64(s, 16);
                IntPtr read;
                Array.Clear(buf, 0, PAGE);
                if (ReadProcessMemory(h, (IntPtr)a, buf, (IntPtr)PAGE, out read)) { fs.Write(buf, 0, PAGE); mp.WriteLine(a.ToString("X") + " " + PAGE); }
            }
        }
        CloseHandle(h);
        return "pages=" + pages.Length;
    }

    public static string Dump(int pid, string pagesFile, string outBin)
    {
        IntPtr h = OpenProcess(0x410, false, pid);
        if (h == IntPtr.Zero) return "OPEN_FAIL";
        var pages = File.ReadAllLines(pagesFile);
        using (var fs = new FileStream(outBin, FileMode.Create, FileAccess.Write))
        {
            var buf = new byte[PAGE];
            foreach (var line in pages)
            {
                string s = line.Trim();
                if (s.Length == 0) continue;
                long a = Convert.ToInt64(s, 16);
                IntPtr read;
                Array.Clear(buf, 0, PAGE);
                ReadProcessMemory(h, (IntPtr)a, buf, (IntPtr)PAGE, out read);
                fs.Write(buf, 0, PAGE);
            }
        }
        CloseHandle(h);
        return "dumped=" + pages.Length;
    }
}
"@
Add-Type -TypeDefinition $cs -Language CSharp
$args[0..3] | Out-Null
$mode = $args[0]
if ($mode -eq "hash") { [Scan]::Hash([int]$args[1], $args[2]) }
elseif ($mode -eq "dump") { [Scan]::Dump([int]$args[1], $args[2], $args[3]) }
elseif ($mode -eq "dumpchanged") { [Scan]::DumpChanged([int]$args[1], $args[2], $args[3], $args[4], $args[5]) }
elseif ($mode -eq "dumppages") { [Scan]::DumpPages([int]$args[1], $args[2], $args[3], $args[4]) }
elseif ($mode -eq "dumpsmall") { [Scan]::DumpSmall([int]$args[1], $args[2], $args[3], [int64]$args[4]) }
else { "usage: hash <pid> <out> | dump <pid> <pages> <outbin>" }
