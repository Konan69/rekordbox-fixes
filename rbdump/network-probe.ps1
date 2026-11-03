Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class RbNet {
[DllImport("wininet.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr InternetOpenW(string agent,uint access,string proxy,string bypass,uint flags);
[DllImport("wininet.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr InternetOpenUrlW(IntPtr h,string url,string headers,uint headersLength,uint flags,IntPtr context);
[DllImport("wininet.dll",SetLastError=true)] static extern bool InternetCloseHandle(IntPtr h);
[DllImport("wininet.dll",SetLastError=true)] static extern bool InternetSetOptionW(IntPtr h,uint option,ref int value,int length);
[DllImport("wininet.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool HttpQueryInfoW(IntPtr h,uint info,ref uint data,ref uint length,IntPtr index);
public static string Probe(uint access,string url) {
 var h=InternetOpenW("rekordbox-network-diagnostic",access,null,null,0);
 int limit=5000; foreach(uint opt in new uint[]{2,5,6}) InternetSetOptionW(h,opt,ref limit,4);
 var sw=Stopwatch.StartNew(); var r=InternetOpenUrlW(h,url,null,0,0x84000200,IntPtr.Zero); var err=Marshal.GetLastWin32Error();
 uint status=0,n=4;if(r!=IntPtr.Zero){HttpQueryInfoW(r,0x20000013,ref status,ref n,IntPtr.Zero);InternetCloseHandle(r);} InternetCloseHandle(h);
 return "access="+access+" elapsedMs="+sw.ElapsedMilliseconds+" http="+status+" transportError="+(r==IntPtr.Zero?err:0);
}
}
"@
foreach($access in 0,1){[RbNet]::Probe($access,"https://accounts.us1.gigya.com/accounts.login")}
