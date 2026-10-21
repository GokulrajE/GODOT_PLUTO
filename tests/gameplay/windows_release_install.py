"""Real Windows exported-app install/restart test in an isolated profile."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[2]
base = root / '.godot' / ('windows-real-update-' + str(int(time.time())))
target = base / 'installed'
shutil.copytree(root / 'builds/shared-updater/windows', target)
env = os.environ.copy()
env['APPDATA'] = str(base / 'profile/AppData/Roaming')
env['USERPROFILE'] = str(base / 'profile')
cache = Path(env['APPDATA']) / 'Godot/app_userdata/PLUTO/updates'
cache.mkdir(parents=True)
package = cache / 'package-123.zip'
shutil.copy2(root / 'releases/shared-updater-verified-v1.0.6/windows/PLUTO-windows-x86_64.zip', package)
(target / 'unrelated-record.txt').write_text('must remain')
print('TEST_DIRECTORY=' + str(base), flush=True)
with (base / 'initial.log').open('wb') as log:
    original = subprocess.Popen([str(target / 'PLUTO.exe'), '--headless', '--quit-after', '600'],
        cwd=target, env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW)
token = '123-456'
job = dict(pid=original.pid, target=str(target), executable='PLUTO.exe',
           package=str(package), sha256=hashlib.sha256(package.read_bytes()).hexdigest(),
           version='1.0.6', token=token, cache=str(cache), platform='windows-x86_64')
jobfile = cache / ('job-' + token + '.json')
jobfile.write_text(json.dumps(job))
helper = subprocess.Popen([str(root / 'tools/update/bin/PLUTOUpdater.exe'), str(jobfile)], env=env,
                          creationflags=subprocess.CREATE_NO_WINDOW)
helper.wait(timeout=150)
original.wait(timeout=15)
status = json.loads((cache / 'updater-status.json').read_text())
print(json.dumps(status), flush=True)
assert status['state'] == 'complete', status
assert (target / 'unrelated-record.txt').read_text() == 'must remain'
assert not package.exists() and not jobfile.exists()
assert not (cache / ('install-' + token)).exists()
manifest = json.loads((target / 'app-release.json').read_text())
for item in manifest['files']:
    assert hashlib.sha256((target / item['path']).read_bytes()).hexdigest() == item['sha256']
print('PASS: actual exported Windows app installed, restarted, acknowledged startup; all installed hashes match; cache cleaned; unrelated data preserved', flush=True)
