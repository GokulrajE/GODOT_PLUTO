$ErrorActionPreference='Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixtureRoot = Join-Path $repoRoot ('.godot/updater-install-tests/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
$csc = 'C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$checks = 0
function Check([bool]$ok,[string]$label) { if (-not $ok) { throw "FAIL: $label" }; $script:checks++ }
function Compile([string]$body,[string]$path) {
    $source = $path + '.cs'
    $body | Set-Content -LiteralPath $source -Encoding UTF8
    & $csc /nologo /target:winexe "/out:$path" $source
    if ($LASTEXITCODE -ne 0) { throw 'Fixture compile failed' }
}
$oldExe = Join-Path $fixtureRoot 'old.exe'
Compile 'class App { static void Main() {} }' $oldExe
foreach ($mode in @('success','failed-startup','bad-hash','traversal','wrong-version')) {
    $caseRoot = Join-Path $fixtureRoot $mode
    $target = Join-Path $caseRoot 'installed'
    $cache = Join-Path $caseRoot 'cache'
    $build = Join-Path $caseRoot 'build'
    New-Item -ItemType Directory -Path $target,$cache,$build -Force | Out-Null
    Copy-Item -LiteralPath $oldExe -Destination (Join-Path $target 'PLUTO.exe')
    'keep-this-patient-record' | Set-Content -LiteralPath (Join-Path $target 'patient-fixture.txt')
    $cacheLiteral = $cache.Replace('\','\\')
    $program = 'using System; using System.IO; class App { static void Main(string[] args) { for(int i=0;i<args.Length-1;i++) if(args[i]=="--pluto-update-token") File.WriteAllText("' + $cacheLiteral + '\\ack-"+args[i+1], "1.0.1"); System.Threading.Thread.Sleep(1500); } }'
    if ($mode -eq 'failed-startup') { $program = 'class App { static void Main() { System.Environment.Exit(1); } }' }
    $compiled = Join-Path $caseRoot 'new.exe'
    Compile $program $compiled
    Copy-Item -LiteralPath $compiled -Destination (Join-Path $build 'PLUTO.exe')
    'new-content' | Set-Content -LiteralPath (Join-Path $build 'asset.txt')
    $version = if ($mode -eq 'wrong-version') { '9.0.0' } else { '1.0.1' }
    & (Join-Path $repoRoot 'tools/update/package-release.ps1') -BuildDirectory $build -Version $version -OutputDirectory (Join-Path $caseRoot 'release') | Out-Null
    $zip = Join-Path $cache 'package-12345.zip'
    Copy-Item -LiteralPath (Join-Path $caseRoot 'release/PLUTO-windows-x86_64.zip') -Destination $zip
    'unrelated-cache-file' | Set-Content -LiteralPath (Join-Path $cache 'keep.txt')
    if ($mode -eq 'traversal') {
        $archive = [IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Update)
        $entry = $archive.CreateEntry('../escaped.txt')
        $writer = [IO.StreamWriter]::new($entry.Open()); $writer.Write('bad'); $writer.Dispose(); $archive.Dispose()
    }
    $digest = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($mode -eq 'bad-hash') { $digest = 'a' * 64 }
    $job = @{pid=2147483647;target=$target;executable='PLUTO.exe';package=$zip;sha256=$digest;version='1.0.1';token='12345';cache=$cache}
    $jobPath = Join-Path $cache 'job-12345.json'
    $job | ConvertTo-Json | Set-Content -LiteralPath $jobPath -Encoding UTF8
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools/update/install-update.ps1') -JobPath $jobPath
    $status = Get-Content -LiteralPath (Join-Path $cache 'updater-status.json') -Raw | ConvertFrom-Json
    if ($mode -eq 'success') {
        Check ($status.state -eq 'complete') 'successful install and startup acknowledgement'
        Check ((Get-FileHash (Join-Path $target 'PLUTO.exe')).Hash -eq (Get-FileHash $compiled).Hash) 'new executable installed'
        Check (Test-Path -LiteralPath (Join-Path $target 'asset.txt')) 'new assets installed'
        Check (-not (Test-Path -LiteralPath $zip)) 'successful download removed'
        Check (-not (Test-Path -LiteralPath (Join-Path $cache 'install-12345'))) 'successful stage and backup removed'
        Check (-not (Test-Path -LiteralPath $jobPath)) 'completed job removed'
        Check (-not (Test-Path -LiteralPath (Join-Path $cache 'ack-12345'))) 'startup acknowledgement removed'
        Check (-not (Test-Path -LiteralPath (Join-Path $cache 'ready-12345'))) 'ready marker removed'
    } else {
        Check ($status.state -eq 'failed') "$mode rejected"
        Check ((Get-FileHash (Join-Path $target 'PLUTO.exe')).Hash -eq (Get-FileHash $oldExe).Hash) "$mode original executable preserved"
        Check (-not (Test-Path -LiteralPath (Join-Path $target 'asset.txt'))) "$mode no new asset left behind"
        Check (Test-Path -LiteralPath $zip) "$mode downloaded package retained"
        Check (Test-Path -LiteralPath $jobPath) "$mode diagnostic job retained"
        if ($mode -eq 'failed-startup') { Check (Test-Path -LiteralPath (Join-Path $cache 'install-12345/backup/PLUTO.exe')) 'failed startup retains rollback backup' }
    }
    Check ((Get-Content -LiteralPath (Join-Path $target 'patient-fixture.txt')).Trim() -eq 'keep-this-patient-record') "$mode unrelated records untouched"
    Check (Test-Path -LiteralPath (Join-Path $cache 'keep.txt')) "$mode unrelated cache file preserved"
    Check (-not (Test-Path -LiteralPath (Join-Path $cache 'install-12345/escaped.txt'))) "$mode no path escape"
    Write-Output "$mode : $($status.state) - $($status.message)"
}
Write-Output "INSTALLER: $checks checks passed"
