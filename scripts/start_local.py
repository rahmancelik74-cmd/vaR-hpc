"""Build current sources, then serve the local application. No third-party packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def build(cuda=False, openmp=True):
    env = os.environ.copy()
    if os.name == 'nt':
        env = {k.upper(): v for k, v in env.items()}
        vswhere = Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)'))/'Microsoft Visual Studio/Installer/vswhere.exe'
        install = subprocess.check_output([str(vswhere), '-latest', '-property', 'installationPath'], text=True).strip()
        setup = Path(install)/'Common7/Tools/VsDevCmd.bat'
        # This is a fixed trusted developer-environment command, never browser input.
        output = subprocess.check_output(f'cmd.exe /d /s /c ""{setup}" -arch=x64 -host_arch=x64 >nul && set"', text=True)
        for line in output.splitlines():
            key, sep, value = line.partition('=')
            if sep and key:
                env[key.upper()] = value
    folder = ROOT/('build-local-app-cuda' if cuda else ('build-local-app' if openmp else 'build-local-app-serial'))
    compiler = []
    if cuda:
        compiler += ['-DCMAKE_CUDA_ARCHITECTURES=native']
    if os.name == 'nt':
        compiler += ['-DCMAKE_CXX_COMPILER='+str(Path(install)/'VC/Tools/MSVC'/env['VCTOOLSVERSION'].strip('/\\')/'bin/Hostx64/x64/cl.exe')]
    subprocess.run(['cmake', '--fresh', '-S', str(ROOT), '-B', str(folder), '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
                    '-DMC_ENABLE_CUDA='+('ON' if cuda else 'OFF'), '-DMC_ENABLE_OPENMP='+('ON' if openmp else 'OFF'),
                    '-DMC_BUILD_CPU_TOOLS=OFF', '-DBUILD_TESTING=ON']+compiler, check=True, env=env)
    subprocess.run(['cmake', '--build', str(folder), '--parallel', '4'], check=True, env=env)
    executable = folder/('mc_var.exe' if os.name == 'nt' else 'mc_var')
    manifest = {'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
                'source_sha256': source_hash(), 'configuration': 'Release', 'cuda': cuda, 'openmp': openmp}
    (folder/'local-app-build.json').write_text(json.dumps(manifest), encoding='ascii')
    return executable


def source_hash():
    h = hashlib.sha256()
    paths = [ROOT/'CMakeLists.txt'] + sorted((ROOT/'src').glob('*')) + sorted((ROOT/'include').rglob('*'))
    for path in paths:
        if path.is_file():
            h.update(path.relative_to(ROOT).as_posix().encode('ascii'))
            h.update(path.read_bytes())
    return h.hexdigest()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cuda', action='store_true', help='Build CUDA explicitly; no fallback')
    parser.add_argument('--serial-only', action='store_true')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--executable', type=Path, help='Administrator/operator configured build with matching local-app-build.json')
    args = parser.parse_args()
    from local_app.server import serve
    serve(args.executable or build(args.cuda, not args.serial_only), args.port)
