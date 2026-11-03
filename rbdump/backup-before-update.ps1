param([string]$OutputDirectory = (Join-Path $env:USERPROFILE "rbdump"))
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$ErrorActionPreference="Stop"
$p=Get-Process rekordbox -ErrorAction SilentlyContinue
if($p){
 [void]$p.CloseMainWindow()
 if(-not $p.WaitForExit(15000)){throw "rekordbox has not closed cleanly; backup cancelled"}
}
$dest=(Join-Path $OutputDirectory "before-update-")+(Get-Date -Format yyyyMMdd-HHmmss)
New-Item -ItemType Directory -Path $dest | Out-Null
foreach($name in "rekordbox","rekordbox6"){
 $target=Join-Path $dest $name
 New-Item -ItemType Directory -Path $target | Out-Null
 Get-ChildItem (Join-Path $env:APPDATA "Pioneer\$name") -File | Copy-Item -Destination $target
}
"BACKUP="+$dest
(Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum
