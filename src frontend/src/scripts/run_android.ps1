# Run Flutter on Android using D: for temp/cache (avoids C: disk-full errors).
$cacheRoot = 'D:\dev-cache'
$dirs = @(
    "$cacheRoot\temp",
    "$cacheRoot\pub-cache",
    'D:\gradle-home'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

$env:TEMP = "$cacheRoot\temp"
$env:TMP = "$cacheRoot\temp"
$env:PUB_CACHE = "$cacheRoot\pub-cache"
$env:GRADLE_USER_HOME = 'D:\gradle-home'

& "$PSScriptRoot\free_c_drive_cache.ps1"

Set-Location (Join-Path $PSScriptRoot '..')
flutter run @args
