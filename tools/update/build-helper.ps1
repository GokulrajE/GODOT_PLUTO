param()
$ErrorActionPreference='Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& python -m PyInstaller --noconfirm --clean --onefile --name PLUTOUpdater --distpath (Join-Path $PSScriptRoot 'bin') --workpath (Join-Path $root '.godot/updater-build') --specpath (Join-Path $root '.godot') (Join-Path $PSScriptRoot 'install-update.py')
if ($LASTEXITCODE -ne 0) { throw 'Updater compilation failed' }
(Get-FileHash (Join-Path $PSScriptRoot 'install-update.py') -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content (Join-Path $PSScriptRoot 'bin/PLUTOUpdater.source.sha256')
