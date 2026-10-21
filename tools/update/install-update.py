"""Shared Windows/Linux portable-install updater. Standard library only."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import time
import zipfile


def digest(path):
    with open(path, 'rb') as stream:
        result = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
        return result.hexdigest()


def no_links(path):
    for part in (path, *path.parents):
        if part.is_symlink() or (os.name == 'nt' and part.exists() and getattr(part.lstat(), 'st_file_attributes', 0) & 0x400):
            raise ValueError('Linked installation/cache paths are not supported')


def safe(root, name):
    if not name or '\\' in name or ':' in name or name.startswith('/') or any(
            p in ('', '.', '..') or p.endswith(('.', ' ')) for p in name.split('/')):
        raise ValueError('Unsafe package path: ' + name)
    path = root / name
    if os.name == 'nt' and any(Path(p).is_reserved() for p in name.split('/')):
        raise ValueError('Reserved Windows path')
    no_links(path)
    return path


def prepare(job, stage):
    package = Path(job['package'])
    if digest(package) != job['sha256'].lower():
        raise ValueError('ZIP checksum mismatch')
    names = set()
    with zipfile.ZipFile(package) as archive:
        expanded = 0
        for info in archive.infolist():
            expanded += info.file_size
            if expanded > 2147483648 or len(names) >= 20000:
                raise ValueError('Extraction limits exceeded')
            name = info.filename
            destination = safe(stage, name.rstrip('/'))
            if stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError('ZIP symlinks are not allowed')
            if name.split('/')[0] in ('data', 'Documents', '.git', '.godot') or Path(name).name in ('device.cfg', 'settings.cfg', 'project.godot'):
                raise ValueError('Protected data in package')
            if info.is_dir():
                continue
            if name in names or (os.name == 'nt' and name.casefold() in {n.casefold() for n in names}):
                raise ValueError('Duplicate ZIP entry')
            names.add(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, destination.open('xb') as output:
                shutil.copyfileobj(source, output)
    manifest = json.loads((stage / 'app-release.json').read_text(encoding='utf-8-sig'))
    for key in ('version', 'executable', 'platform'):
        actual = manifest.get(key, 'windows-x86_64' if key == 'platform' and job['executable'] == 'PLUTO.exe' else None)
        if actual != job[key]:
            raise ValueError('Release manifest does not match ' + key)
    listed = set()
    for item in manifest['files']:
        name = item['path']
        if name in listed or name == 'app-release.json':
            raise ValueError('Invalid manifest file list')
        listed.add(name)
        if digest(safe(stage, name)) != item['sha256'].lower():
            raise ValueError('Invalid file checksum: ' + name)
        safe(Path(job['target']), name)
    if job['executable'] not in listed or names != listed | {'app-release.json'}:
        raise ValueError('Missing or unlisted package files')
    return sorted(listed) + ['app-release.json']


def alive(pid):
    if os.name == 'nt':
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x100000, False, pid)
        if not handle:
            if ctypes.get_last_error() == 87: return False
            raise OSError('Cannot inspect installed application process')
        try:
            return kernel.WaitForSingleObject(handle, 0) == 258
        finally:
            kernel.CloseHandle(handle)
    # A stopped app can remain a zombie briefly while its launcher exits.
    # kill(pid, 0) alone incorrectly treats that as a running application.
    try:
        proc_state = Path('/proc') / str(pid) / 'stat'
        if proc_state.exists() and proc_state.read_text().rsplit(')', 1)[1].split()[0] == 'Z':
            return False
    except (OSError, IndexError):
        pass
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def detach_helper():
    """Keep the helper alive when the exported .sh launcher/terminal closes."""
    if os.name == 'posix':
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        if os.getsid(0) != os.getpid():
            try:
                os.setsid()
            except PermissionError:
                # Some launchers already make the child a process-group leader.
                # Ignoring SIGHUP and redirecting stdio still isolates terminal loss.
                pass


def lock_install(lock):
    if os.name == 'nt':
        import msvcrt
        lock.write(b'0')
        lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
    else:
        import fcntl
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)


def launch_app(target, executable, cache, token=None):
    args = [str(target / executable)]
    if token is not None:
        args += ['--', '--pluto-update-token', token]
    # Never inherit a disappearing terminal's input/output. Retain DISPLAY,
    # WAYLAND_DISPLAY, XDG_RUNTIME_DIR and the rest of the desktop environment.
    log_name = 'restart-' + token + '.log' if token else 'rollback-restart.log'
    with (cache / log_name).open('ab') as log:
        return subprocess.Popen(args, cwd=target, stdin=subprocess.DEVNULL,
                                stdout=log, stderr=subprocess.STDOUT,
                                start_new_session=True, close_fds=True)


def install(job_path):
    job_path = Path(job_path).absolute()
    job = json.loads(job_path.read_text(encoding='utf-8-sig'))
    if job.get('executable') == 'PLUTO.exe': job.setdefault('platform', 'windows-x86_64')
    cache, target = Path(job['cache']).absolute(), Path(job['target']).absolute()
    no_links(cache)
    no_links(target)
    token = job['token']
    if not re.fullmatch(r'[0-9-]+', token) or not re.fullmatch(r'\d+\.\d+\.\d+', job['version']):
        raise ValueError('Invalid update job')
    expected = {'windows-x86_64': 'PLUTO.exe', 'linux-arm64': 'PLUTO.arm64', 'linux-x86_64': 'PLUTO.x86_64'}
    if expected.get(job.get('platform')) != job['executable']:
        raise ValueError('Unsupported platform/executable')
    if job_path != cache / ('job-' + token + '.json'):
        raise ValueError('Job outside cache')
    work = cache / ('install-' + token)
    stage, backup = work / 'stage', work / 'backup'
    ready, ack = cache / ('ready-' + token), cache / ('ack-' + token)
    changed = []
    process = None
    exited = False

    def status(state, message):
        (cache / 'updater-status.json').write_text(json.dumps(dict(
            state=state, message=message, version=job['version'],
            backup=str(backup) if backup.exists() else '', time=time.time())))

    try:
        with (cache / 'update-install.lock').open('a+b') as lock:
            lock_install(lock)
            if (target / 'project.godot').exists() or not (target / job['executable']).is_file():
                raise ValueError('Not an exported installation')
            if work.exists() or ready.exists() or ack.exists():
                raise ValueError('Update token already used')
            stage.mkdir(parents=True)
            backup.mkdir()
            files = prepare(job, stage)
            probe = target / ('.pluto-update-' + token)
            with probe.open('x') as stream:
                stream.write('probe')
            probe.unlink()
            status('ready', 'Verified; waiting for application exit')
            ready.write_text('ready')
            deadline = time.monotonic() + 30
            while alive(int(job['pid'])):
                if time.monotonic() > deadline:
                    raise TimeoutError('Application did not close')
                time.sleep(.1)
            exited = True
            for name in files:
                dest = safe(target, name)
                old = safe(backup, name)
                existed = dest.exists()
                if existed:
                    old.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dest, old)
                changed.append((name, existed))
                (work / 'rollback.json').write_text(json.dumps(changed))
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(stage / name, dest)
            executable = target / job['executable']
            executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
            status('restarting', 'Files installed; launching application')
            process = launch_app(target, job['executable'], cache, token)
            deadline = time.monotonic() + 45
            while not (ack.exists() and ack.read_text().strip() == job['version']):
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Updated application did not confirm startup (exit=%s); see restart-%s.log' % (process.poll(), token))
                time.sleep(.2)
            status('complete', 'Update installed and startup confirmed')
            # Cleanup failure must never roll back a confirmed running application.
            try:
                shutil.rmtree(work)
                ready.unlink(missing_ok=True)
                ack.unlink(missing_ok=True)
                package = Path(job['package']).absolute()
                if package.parent == cache and re.fullmatch(r'package-\d+\.zip', package.name):
                    package.unlink(missing_ok=True)
                job_path.unlink()
                status('complete', 'Update installed; cache cleaned')
            except OSError as error:
                status('complete', 'Installed; cache cleanup pending: ' + str(error))
    except Exception as error:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for name, existed in reversed(changed):
            dest = safe(target, name)
            if existed:
                shutil.copy2(safe(backup, name), dest)
            else:
                dest.unlink(missing_ok=True)
        status('failed', str(error) + '; original application preserved/restored')
        if exited:
            try:
                launch_app(target, job['executable'], cache)
            except OSError as restart_error:
                status('failed', str(error) + '; original files restored but restart failed: ' + str(restart_error))
        return 1
    return 0


if __name__ == '__main__':
    detach_helper()
    # Capture Python/native launch errors even after the original terminal closes.
    log_path = Path(sys.argv[1]).absolute().parent / 'installer.log'
    no_links(log_path)
    with open(os.devnull, 'rb') as source, log_path.open('ab', buffering=0) as log:
        os.dup2(source.fileno(), 0)
        os.dup2(log.fileno(), 1)
        os.dup2(log.fileno(), 2)
    sys.exit(install(sys.argv[1]))
