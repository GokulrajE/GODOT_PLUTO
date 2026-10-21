"""Package a Linux Godot export on Windows or Linux using Python 3."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def package(build, output, version, arch, system='linux'):
    import re
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Use a stable version such as 1.0.5')
    build, output = Path(build).resolve(), Path(output).resolve()
    executable = 'PLUTO.exe' if system == 'windows' else 'PLUTO.' + arch
    if not (build / executable).is_file() or (build / 'project.godot').exists():
        raise ValueError('Use an exported folder containing ' + executable)
    if output == build or build in output.parents:
        raise ValueError('Output must be outside the build folder')
    files = []
    for path in sorted(build.rglob('*')):
        if path.is_symlink():
            raise ValueError('Export must not contain symlinks')
        if not path.is_file():
            continue
        name = path.relative_to(build).as_posix()
        if name.split('/')[0] in ('data', 'Documents', '.git', '.godot', 'tests', 'docs', 'builds', 'releases'):
            continue
        if path.name in ('app-release.json', 'device.cfg', 'settings.cfg') or path.suffix in ('.log', '.translation'):
            continue
        files.append(dict(path=name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    manifest = dict(version=version, executable=executable, platform=system + '-' + arch, files=files)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / ('PLUTO-' + system + '-' + arch + '.zip')
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as target:
        for item in files:
            target.write(build / item['path'], item['path'])
        target.writestr('app-release.json', json.dumps(manifest, indent=2))
    (build / 'app-release.json').write_text(json.dumps(manifest, indent=2))
    archive.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest())
    return archive


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--build', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--arch', choices=['arm64', 'x86_64'], default='arm64')
    parser.add_argument('--platform', choices=['windows', 'linux'], required=True)
    args = parser.parse_args()
    if args.platform == 'windows' and args.arch != 'x86_64':
        parser.error('Windows currently supports x86_64 only')
    print(package(args.build, args.output, args.version, args.arch, args.platform))
