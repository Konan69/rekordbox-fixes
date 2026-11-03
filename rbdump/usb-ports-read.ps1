param([Parameter(Mandatory=$true)][string]$HubPath)
Add-Type @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class UsbPortRead {
[DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string path,uint access,uint share,IntPtr security,uint disposition,uint flags,IntPtr template);
[DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(SafeFileHandle h,uint code,byte[] input,uint inputLength,byte[] output,uint outputLength,out uint returned,IntPtr overlapped);
public static void Read(string path,int port) {
 using(var h=CreateFile(path,0,3,IntPtr.Zero,3,0,IntPtr.Zero)) {
  if(h.IsInvalid){Console.WriteLine("HubOpenError="+Marshal.GetLastWin32Error());return;}
  var data=new byte[2048];Array.Copy(BitConverter.GetBytes(port),data,4);uint returned;
  if(!DeviceIoControl(h,0x220448,data,4,data,(uint)data.Length,out returned,IntPtr.Zero)){Console.WriteLine("Port="+port+" QueryError="+Marshal.GetLastWin32Error());return;}
  Console.WriteLine("Port="+port+" Returned="+returned+" Status="+BitConverter.ToUInt32(data,31)+" Vendor="+BitConverter.ToUInt16(data,12).ToString("X4")+" Product="+BitConverter.ToUInt16(data,14).ToString("X4"));
 }
}
}
"@
foreach($port in 1..24){[UsbPortRead]::Read($HubPath,$port)}
