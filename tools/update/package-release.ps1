param([Parameter(Mandatory=$true)][string]$BuildDirectory,[Parameter(Mandatory=$true)][string]$Version,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a stable version such as 1.0.1' }
$buildRoot = (Resolve-Path -LiteralPath $BuildDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $buildRoot 'PLUTO.exe'))) { throw 'Export the game as PLUTO.exe first' }
if (Test-Path -LiteralPath (Join-Path $buildRoot 'project.godot')) { throw 'Use an exported build folder, not the source project' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
if ($outputRoot.StartsWith($buildRoot + '\',[StringComparison]::OrdinalIgnoreCase) -or $outputRoot -eq $buildRoot) { throw 'Output folder must be outside the exported build folder' }
$archive = Join-Path $outputRoot 'PLUTO-windows-x86_64.zip'
$stageRoot = Join-Path $outputRoot '.package-stage'
if (Test-Path -LiteralPath $archive) { throw 'Output ZIP already exists; choose a fresh release directory' }
if (Test-Path -LiteralPath $stageRoot) { throw 'Package staging folder already exists; inspect it before retrying' }
$files = @(Get-ChildItem -LiteralPath $buildRoot -Recurse -File | Where-Object {
    $relative = $_.FullName.Substring($buildRoot.Length+1).Replace([char]92,[char]47)
    $_.Name -ne 'app-release.json' -and
    $relative -notmatch '^(data|\.git|\.godot|Documents|tests|docs|builds|releases|graphify-out)/' -and
    $_.Name -notin @('device.cfg','settings.cfg') -and
    $_.Extension -notin @('.log','.translation')
})
$manifestFiles = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($buildRoot.Length+1).Replace([char]92,[char]47)
    @{path=$relative; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
if (-not ($manifestFiles | Where-Object { $_.path -eq 'PLUTO.exe' })) { throw 'PLUTO.exe is missing from the package manifest' }
$manifestPath = Join-Path $buildRoot 'app-release.json'
@{version=$Version; executable='PLUTO.exe'; files=$manifestFiles} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
New-Item -ItemType Directory -Path $stageRoot | Out-Null
try {
    foreach ($item in $manifestFiles) {
        $source = Join-Path $buildRoot $item.path.Replace('/', '\')
        $destination = Join-Path $stageRoot $item.path.Replace('/', '\')
        $stagePrefix = [IO.Path]::GetFullPath($stageRoot).TrimEnd('\') + '\'
        if (-not [IO.Path]::GetFullPath($destination).StartsWith($stagePrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Package path escaped staging folder' }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stageRoot 'app-release.json')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stageRoot,$archive)
    (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content -LiteralPath ($archive + '.sha256')
} finally {
    $stageFull = [IO.Path]::GetFullPath($stageRoot)
    if (-not $stageFull.StartsWith($outputRoot.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to clean staging path outside output folder' }
    if (Test-Path -LiteralPath $stageFull) { Remove-Item -LiteralPath $stageFull -Recurse -Force }
}
Write-Output $archive
