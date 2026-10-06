$ErrorActionPreference = 'Stop'

$cacheRoot = Join-Path $env:LOCALAPPDATA 'Mytweak\launch-cache'
$downloadRoot = Join-Path $cacheRoot ("download-" + [guid]::NewGuid().ToString('N'))

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    New-Item -Path $downloadRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null

    $rawRoot = 'https://raw.githubusercontent.com/MohamedJafer11314/mytweak/main'
    $uiPath = Join-Path $downloadRoot 'OptimizerUI.exe'
    $scriptPath = Join-Path $downloadRoot 'full_optimize.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri "$rawRoot/cpp_ui/OptimizerUI.exe" -OutFile $uiPath -ErrorAction Stop
    Invoke-WebRequest -UseBasicParsing -Uri "$rawRoot/full_optimize.ps1" -OutFile $scriptPath -ErrorAction Stop

    $uiHash = (Get-FileHash -LiteralPath $uiPath -Algorithm SHA256).Hash.Substring(0, 12)
    $scriptHash = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.Substring(0, 12)
    $appRoot = Join-Path $cacheRoot "$uiHash-$scriptHash"
    if (Test-Path -LiteralPath $appRoot) {
        Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction Stop
    } else {
        Move-Item -LiteralPath $downloadRoot -Destination $appRoot -ErrorAction Stop
    }

    Start-Process -FilePath (Join-Path $appRoot 'OptimizerUI.exe') -WorkingDirectory $appRoot -ErrorAction Stop
} catch {
    if (Test-Path -LiteralPath $downloadRoot) {
        Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Error "Unable to download or start the optimizer UI: $($_.Exception.Message)"
}