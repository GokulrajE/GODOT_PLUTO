param([Parameter(Mandatory=$true)][string]$JobPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$job = Get-Content -LiteralPath $JobPath -Raw | ConvertFrom-Json
$cacheRoot = [IO.Path]::GetFullPath($job.cache)
$targetRoot = [IO.Path]::GetFullPath($job.target).TrimEnd('\')
$workRoot = Join-Path $cacheRoot ('install-' + $job.token)
$stageRoot = Join-Path $workRoot 'stage'
$backupRoot = Join-Path $workRoot 'backup'
$changed = [Collections.Generic.List[object]]::new()
$ready = $false
$newProcess = $null
function Status([string]$state, [string]$message) {
    @{ state=$state; message=$message; version=$job.version; time=[DateTime]::UtcNow.ToString('o'); backup=$(if (Test-Path -LiteralPath $backupRoot) { $backupRoot } else { '' }) } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $cacheRoot 'updater-status.json') -Encoding UTF8
}
function ClearCompletedUpdate {
    # Only this confirmed update's files, never other jobs or patient storage.
    $paths = @($workRoot, (Join-Path $cacheRoot ('ready-' + $job.token)), (Join-Path $cacheRoot ('ack-' + $job.token)))
    $packagePath = [IO.Path]::GetFullPath($job.package)
    if ([IO.Path]::GetDirectoryName($packagePath) -eq $cacheRoot.TrimEnd('\') -and [IO.Path]::GetFileName($packagePath) -match '^package-[0-9]+\.zip$') { $paths += $packagePath }
    $expectedJob = Join-Path $cacheRoot ('job-' + $job.token + '.json')
    if ([IO.Path]::GetFullPath($JobPath) -eq $expectedJob) { $paths += $expectedJob }
    foreach ($path in $paths) {
        $full = [IO.Path]::GetFullPath($path)
        if (-not $full.StartsWith($cacheRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Cleanup path escaped update cache' }
        if (-not (Test-Path -LiteralPath $full)) { continue }
        NoLinks $full
        if (Test-Path -LiteralPath $full -PathType Container) {
            foreach ($child in Get-ChildItem -LiteralPath $full -Recurse -Force) {
                if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Cleanup refused linked directory contents' }
            }
            Remove-Item -LiteralPath $full -Recurse -Force
        } else { Remove-Item -LiteralPath $full -Force }
    }
}
function SafePath([string]$base, [string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('\') -or $relative.Contains(':') -or $relative.StartsWith('/') -or ($relative.Split('/') | Where-Object { $_ -in @('..','.') -or $_.EndsWith('.') -or $_.EndsWith(' ') })) { throw "Unsafe package path: $relative" }
    $full = [IO.Path]::GetFullPath((Join-Path $base $relative))
    if (-not $full.StartsWith(([IO.Path]::GetFullPath($base).TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escaped its root' }
    return $full
}
function NoLinks([string]$path) {
    $cursor = $path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point not allowed: $cursor" }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
try {
    if ($job.token -notmatch '^[0-9-]+$' -or $job.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid update job' }
    if ($job.executable -ne 'PLUTO.exe') { throw 'Expected installed executable PLUTO.exe' }
    if (Test-Path -LiteralPath (Join-Path $targetRoot 'project.godot')) { throw 'Cannot update a source checkout' }
    if (-not (Test-Path -LiteralPath (Join-Path $targetRoot $job.executable))) { throw 'Installed executable is missing' }
    NoLinks $targetRoot
    NoLinks $cacheRoot
    if ((Get-FileHash -LiteralPath $job.package -Algorithm SHA256).Hash -ne $job.sha256) { throw 'ZIP checksum mismatch' }
    New-Item -ItemType Directory -Path $stageRoot,$backupRoot -Force | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($job.package)
    try {
        $names = @{}
        [long]$expanded = 0
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName
            $expanded += $entry.Length
            if ($expanded -gt 2147483648 -or $names.Count -gt 20000) { throw 'Package exceeds extraction limits' }
            if ($name.EndsWith('/')) { continue }
            if ($names.ContainsKey($name)) { throw 'Duplicate ZIP entry' }
            $names[$name] = $true
            if ($name -match '^(data|\.git|\.godot|Documents)/' -or $name -in @('device.cfg','settings.cfg','project.godot')) { throw 'Package contains protected data or source files' }
            if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Symbolic links are not allowed' }
            $dest = SafePath $stageRoot $name
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false)
        }
    } finally { $zip.Dispose() }
    $manifestPath = Join-Path $stageRoot 'app-release.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.version -ne $job.version -or $manifest.executable -ne $job.executable) { throw 'Release manifest does not match the requested version/executable' }
    if ($manifest.files.Count -lt 1) { throw 'Empty release manifest' }
    $listed = @{}
    foreach ($item in $manifest.files) {
        $path = SafePath $stageRoot $item.path
        if ($listed.ContainsKey($item.path) -or $item.path -eq 'app-release.json') { throw 'Invalid manifest file list' }
        $listed[$item.path] = $true
        if ($item.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256) { throw "Invalid file checksum: $($item.path)" }
        $installPath = SafePath $targetRoot $item.path
        NoLinks $installPath
    }
    if (-not $listed.ContainsKey($job.executable) -or $names.Count -ne ($listed.Count + 1)) { throw 'Unlisted or missing files in package' }
    # Prove the installation folder is writable before asking the running game to exit.
    $probe = Join-Path $targetRoot ('.pluto-update-' + $job.token)
    [IO.File]::WriteAllText($probe,'test')
    Remove-Item -LiteralPath $probe
    Status 'ready' 'Package verified; waiting for the application to close.'
    $parentProcess = Get-Process -Id $job.pid -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText((Join-Path $cacheRoot ('ready-' + $job.token)), 'ready')
    $ready = $true
    if ($parentProcess -and -not $parentProcess.WaitForExit(30000)) { throw 'Application did not close; update cancelled' }
    foreach ($relative in @($manifest.files | ForEach-Object { $_.path }) + @('app-release.json')) {
        $dest = SafePath $targetRoot $relative
        NoLinks $dest
        $backup = SafePath $backupRoot $relative
        $existed = Test-Path -LiteralPath $dest
        if ($existed) {
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backup)) -Force | Out-Null
            Copy-Item -LiteralPath $dest -Destination $backup
        }
        $changed.Add(@{path=$dest; backup=$backup; existed=$existed})
        $changed | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $workRoot 'rollback.json') -Encoding UTF8
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force | Out-Null
        Copy-Item -LiteralPath (SafePath $stageRoot $relative) -Destination $dest -Force
    }
    $newProcess = Start-Process -FilePath (Join-Path $targetRoot $job.executable) -WorkingDirectory $targetRoot -ArgumentList @('--','--pluto-update-token',$job.token) -PassThru
    $ackPath = Join-Path $cacheRoot ('ack-' + $job.token)
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ((Test-Path -LiteralPath $ackPath) -and (Get-Content -LiteralPath $ackPath -Raw).Trim() -eq $job.version) {
            Status 'complete' 'Update installed and application restarted.'
            # Cleanup failure must never roll back a successfully started app.
            try {
                ClearCompletedUpdate
                Status 'complete' 'Update installed and application restarted. Temporary update files removed.'
            } catch {
                Write-Warning ('Update succeeded, but cache cleanup was incomplete: ' + $_.Exception.Message)
            }
            exit 0
        }
        if ($newProcess.HasExited) { throw 'Updated application exited before startup confirmation' }
        Start-Sleep -Milliseconds 200
    }
    throw 'Updated application did not confirm startup'
} catch {
    $failure = $_.Exception.Message
    if ($newProcess -and -not $newProcess.HasExited) { $newProcess.Kill(); $newProcess.WaitForExit() }
    $rollbackFailed = $false
    for ($i=$changed.Count-1; $i -ge 0; $i--) {
        $item = $changed[$i]
        try {
            if ($item.existed) { Copy-Item -LiteralPath $item.backup -Destination $item.path -Force }
            elseif (Test-Path -LiteralPath $item.path) { Remove-Item -LiteralPath $item.path }
        } catch { $rollbackFailed = $true }
    }
    Status 'failed' ($failure + $(if ($rollbackFailed) { ' Rollback incomplete; restore the saved backup.' } else { ' Original application preserved.' }))
    if ($ready -and -not $rollbackFailed -and -not (Get-Process -Id $job.pid -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath (Join-Path $targetRoot $job.executable) -WorkingDirectory $targetRoot
    }
    exit 1
}
