param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [ValidateSet('both','windows','pi')][string]$Platform='both'
)
$ErrorActionPreference='Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = (Resolve-Path -LiteralPath $GodotPath).Path
$config = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw
$match = [regex]::Match($config, '(?m)^config/version="(\d+\.\d+\.\d+)"')
if (-not $match.Success) { throw 'Set a stable application version in project.godot first' }
$version = $match.Groups[1].Value
$targets = if ($Platform -eq 'both') { @('windows','pi') } else { @($Platform) }
foreach ($target in $targets) {
    $destination = Join-Path $root "releases/v$version/$target"
    if (Test-Path -LiteralPath $destination) { throw "Release folder already exists: $destination. Use a new version or move it aside first." }
    if (Test-Path -LiteralPath (Join-Path $root "builds/releases/v$version/$target")) { throw 'Build folder already exists. Use a fresh version or move the previous build aside.' }
}
Push-Location $root
try {
    if ('windows' -in $targets) {
        & (Join-Path $PSScriptRoot 'build-helper.ps1')
    }
    foreach ($target in $targets) {
        $build = Join-Path $root "builds/releases/v$version/$target"
        New-Item -ItemType Directory -Path $build -Force | Out-Null
        $preset = if ($target -eq 'windows') { 'Windows Desktop' } else { 'Linux' }
        $executable = if ($target -eq 'windows') { 'PLUTO.exe' } else { 'PLUTO.arm64' }
        $system = if ($target -eq 'windows') { 'windows' } else { 'linux' }
        $arch = if ($target -eq 'windows') { 'x86_64' } else { 'arm64' }
        & $engine --headless --path $root --export-release $preset (Join-Path $build $executable)
        if ($LASTEXITCODE -ne 0) { throw "Godot export failed for $target" }
        & python (Join-Path $PSScriptRoot 'package-release.py') --platform $system --arch $arch --build $build --output (Join-Path $root "releases/v$version/$target") --version $version
        if ($LASTEXITCODE -ne 0) { throw "Packaging failed for $target" }
    }
} finally { Pop-Location }
