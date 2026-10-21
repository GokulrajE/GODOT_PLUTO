import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import types
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools/update' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


installer = load('install-update')
packager = load('package-release')


class LinuxUpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.build = self.base / 'build'
        self.build.mkdir()
        (self.build / 'PLUTO.arm64').write_bytes(b'linux-executable-fixture')
        (self.build / 'PLUTO.pck').write_bytes(b'pck-fixture')
        (self.build / 'data').mkdir()
        (self.build / 'data/private').write_text('excluded')
        self.archive = packager.package(self.build, self.base / 'release', '1.0.5', 'arm64')
        self.job = dict(package=str(self.archive), sha256=installer.digest(self.archive),
                        target=str(self.build), version='1.0.5', executable='PLUTO.arm64', platform='linux-arm64')

    def test_valid_package(self):
        files = installer.prepare(self.job, self.base / 'stage')
        self.assertEqual(set(files), {'PLUTO.arm64', 'PLUTO.pck', 'app-release.json'})

    def test_wrong_version_and_platform(self):
        for key, value in [('version', '1.0.6'), ('platform', 'linux-x86_64'), ('executable', 'PLUTO.exe')]:
            with self.assertRaises(ValueError):
                installer.prepare(dict(self.job, **{key: value}), self.base / key)

    def test_checksum(self):
        with self.assertRaises(ValueError):
            installer.prepare(dict(self.job, sha256='0' * 64), self.base / 'stage')

    def test_traversal(self):
        for name in ('../outside', '/absolute', 'a/../b', 'a\\b', 'a//b'):
            with self.assertRaises(ValueError):
                installer.safe(self.base, name)

    def test_unlisted_and_protected_files(self):
        for name in ('extra.txt', 'data/private'):
            archive = self.base / (name.replace('/', '-') + '.zip')
            archive.write_bytes(self.archive.read_bytes())
            with zipfile.ZipFile(archive, 'a') as target:
                target.writestr(name, 'unexpected')
            with self.assertRaises(ValueError):
                installer.prepare(dict(self.job, package=str(archive), sha256=installer.digest(archive)), self.base / name.replace('/', '-'))

    def test_existing_zip_not_overwritten(self):
        with self.assertRaises(FileExistsError):
            packager.package(self.build, self.base / 'release', '1.0.5', 'arm64')

    def run_install(self, success):
        target, cache = self.base / 'installed', self.base / 'cache'
        target.mkdir()
        cache.mkdir()
        (target / 'PLUTO.arm64').write_bytes(b'old-executable')
        (target / 'patient-record').write_text('preserved')
        package = cache / 'package-123.zip'
        package.write_bytes(self.archive.read_bytes())
        job = dict(self.job, target=str(target), cache=str(cache), package=str(package), pid=123, token='123-456')
        path = cache / 'job-123-456.json'
        path.write_text(json.dumps(job))
        launches = []
        def launch(args, **kwargs):
            launches.append(args)
            if success and '--pluto-update-token' in args:
                (cache / 'ack-123-456').write_text('1.0.5')
            return mock.Mock(poll=lambda: 0)
        fake_fcntl = types.SimpleNamespace(LOCK_EX=1, LOCK_NB=2, flock=lambda *args: None)
        with mock.patch.dict('sys.modules', fcntl=fake_fcntl), mock.patch.object(installer, 'alive', return_value=False), mock.patch.object(installer.subprocess, 'Popen', side_effect=launch):
            result = installer.install(path)
        self.assertEqual((target / 'patient-record').read_text(), 'preserved')
        if success:
            self.assertEqual(result, 0)
            self.assertEqual((target / 'PLUTO.arm64').read_bytes(), b'linux-executable-fixture')
            self.assertFalse(package.exists())
            self.assertFalse(path.exists())
            self.assertFalse((cache / 'install-123-456').exists())
        else:
            self.assertEqual(result, 1)
            self.assertEqual((target / 'PLUTO.arm64').read_bytes(), b'old-executable')
            self.assertFalse((target / 'PLUTO.pck').exists())
            self.assertTrue(package.exists())
            self.assertEqual(len(launches), 2)

    def test_install_and_cleanup_mocked_process(self):
        self.run_install(True)

    def test_startup_failure_rollback_mocked_process(self):
        self.run_install(False)

    def test_restart_detached_from_terminal(self):
        with mock.patch.object(installer.subprocess, 'Popen') as launch:
            installer.launch_app(self.build, 'PLUTO.arm64', self.base, '123-456')
        args, kwargs = launch.call_args
        self.assertEqual(args[0][-3:], ['--', '--pluto-update-token', '123-456'])
        self.assertTrue(kwargs['start_new_session'])
        self.assertTrue(kwargs['close_fds'])
        self.assertEqual(kwargs['stdin'], installer.subprocess.DEVNULL)
        self.assertEqual(kwargs['stderr'], installer.subprocess.STDOUT)
        self.assertTrue((self.base / 'restart-123-456.log').exists())
        self.assertNotIn('env', kwargs)  # inherit the launching desktop environment

    def test_helper_detaches_before_parent_exits(self):
        with mock.patch.object(installer.os, 'name', 'posix'), \
                mock.patch.object(installer.signal, 'SIGHUP', 1, create=True), \
                mock.patch.object(installer.signal, 'signal') as handler, \
                mock.patch.object(installer.os, 'getsid', return_value=1, create=True), \
                mock.patch.object(installer.os, 'getpid', return_value=2), \
                mock.patch.object(installer.os, 'setsid', create=True) as detach:
            installer.detach_helper()
            detach.assert_called_once()
            handler.assert_called_once_with(1, installer.signal.SIG_IGN)


if __name__ == '__main__':
    unittest.main()
