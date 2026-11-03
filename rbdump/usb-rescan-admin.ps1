param([string]$OutputDirectory = (Join-Path $env:USERPROFILE "rbdump"))
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$ErrorActionPreference = 'Stop'
$out = (Join-Path $OutputDirectory "usb-rescan-result.txt")
& pnputil.exe /scan-devices 2>&1 | Out-File -FilePath $out -Encoding utf8
$scanExit = $LASTEXITCODE
('ScanExit=' + $scanExit) | Out-File -FilePath $out -Append -Encoding utf8
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
 Where-Object { $_.FriendlyName -match 'FLX4' -or $_.InstanceId -match 'VID_2B73' } |
 Select-Object Status,Class,FriendlyName |
 Format-Table -AutoSize | Out-String |
 Out-File -FilePath $out -Append -Encoding utf8
('Completed=' + (Get-Date -Format o)) | Out-File -FilePath $out -Append -Encoding utf8
