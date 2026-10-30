"""Entry point for the bundled CPython runtime; never builds or accesses Git."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import threading
import time
import traceback
import urllib.request

sys.dont_write_bytecode = True
RESOURCES = Path(__file__).resolve().parent
sys.path.insert(0, str(RESOURCES))


def verify(root):
    manifest = json.loads((root/'package-manifest.json').read_text(encoding='ascii'))
    for name, expected in manifest['files'].items():
        path = (root/name).resolve()
        if not path.is_relative_to(root) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Missing or modified package asset: '+name)
    return manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state-dir', required=True, type=Path)
    parser.add_argument('--no-browser', action='store_true')
    args = parser.parse_args()
    state = args.state_dir.resolve()
    state.mkdir(parents=True, exist_ok=True)
    server = app = None
    try:
        if sys.getwindowsversion().build < 20348:
            raise RuntimeError('Supported platforms: Windows 11 x64 or Windows Server 2022 x64.')
        root = RESOURCES.parent.resolve()
        manifest = verify(root)
        ps = Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
        if not ps.is_file():
            raise RuntimeError('Windows PowerShell 5.1 is required. Restore this built-in Windows component.')
        from local_app.server import Application, Server
        workspace = Path(os.environ['LOCALAPPDATA'])/'MCLabPortable'/'workspace'
        workspace.mkdir(parents=True, exist_ok=True)
        app = Application(RESOURCES/'bin/mc_var.exe', workspace=workspace, package=manifest)
        if not app.capabilities['openmp']['available']:
            raise RuntimeError('The bundled OpenMP startup probe failed. Extract the complete ZIP and inspect private startup diagnostics.')
        server = Server(('127.0.0.1',0),app)
        thread = threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{server.server_port}'
        with urllib.request.urlopen(url+'/api/info',timeout=10) as response:
            ready = json.load(response)
        if ready['build']['sha256'] != app.identity['sha256']:
            raise RuntimeError('Readiness identity mismatch')
        (state/'ready.txt').write_text(url,encoding='ascii')
        (state/'service.json').write_text(json.dumps({'pid':os.getpid(),'url':url,'workspace':str(workspace),'source_revision':manifest['source_revision']}),encoding='utf-8')
        # The native parent opens the browser, outside its owned process Job.
        while not (state/'stop.request').exists():
            time.sleep(.1)
        return 0
    except Exception as exc:
        (state/'startup-error.txt').write_text(str(exc)+'\n'+traceback.format_exc(),encoding='utf-8')
        return 1
    finally:
        if server:
            server.shutdown()
        if app:
            with app.lock:
                active = app.active
                if active:
                    active['cancel'].set()
            deadline = time.monotonic()+15
            while app.active and time.monotonic()<deadline:
                time.sleep(.05)
        if server:
            server.server_close()


if __name__ == '__main__':
    sys.exit(main())
