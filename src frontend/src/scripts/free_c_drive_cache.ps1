# Safe cleanup when C: is full — removes Flutter/Dart temp build artifacts.
$temp = $env:LOCALAPPDATA + '\Temp'
$patterns = @('flutter_tools.*', 'flutter_tool.*', 'dart-code-*', 'ps-state-out-*')

foreach ($pattern in $patterns) {
    Get-ChildItem $temp -Filter $pattern -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# Old Gradle wrapper downloads on C: (project uses D:\gradle-home when set)
$gradleC = $env:USERPROFILE + '\.gradle\wrapper\dists'
if (Test-Path $gradleC) {
    Get-ChildItem $gradleC -Directory -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$free = (Get-PSDrive C).Free
Write-Host ("C: free space: {0:N2} GB" -f ($free / 1GB))
