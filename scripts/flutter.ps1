# Convenience wrapper — uses the same Flutter SDK as Cashy
$flutter = "C:\Users\Zeus\Projects\Cashy\.tools\flutter\bin\flutter.bat"
if (-not (Test-Path $flutter)) {
    Write-Error "Flutter SDK not found at $flutter"
    exit 1
}
if (-not $env:ProgramFiles(x86)) {
    Set-Item -Path "Env:ProgramFiles(x86)" -Value "C:\Program Files (x86)"
}
& $flutter @args
