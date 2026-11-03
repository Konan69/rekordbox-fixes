param([string]$OutputDirectory = (Join-Path $env:USERPROFILE "rbdump"))
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System.Runtime.InteropServices;
public class DpiCapture {
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][DpiCapture]::SetProcessDPIAware()
$r=[Windows.Forms.SystemInformation]::VirtualScreen
$b=New-Object Drawing.Bitmap $r.Width,$r.Height
$g=[Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen($r.Location,[Drawing.Point]::Empty,$r.Size)
$b.Save((Join-Path $OutputDirectory "screen-full.png"))
$g.Dispose()
$b.Dispose()
