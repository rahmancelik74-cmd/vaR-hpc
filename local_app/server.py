"""Loopback-only browser adapter for the existing import, calibration and engine tools."""
import base64
import binascii
import csv
import io
import json
import math
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
import calibrate_portfolio as cal
from start_local import source_hash

MAX_FILE = 1024 * 1024
MAX_BODY = 8 * 1024 * 1024
DISK_LIMIT = 512 * 1024 * 1024
TIMEOUT = 120
CALENDAR = ROOT/'data/calendars/nasdaq-us-equities-2023-2025.json'
STATIC = Path(__file__).parent/'static'


def require(test, message):
    if not test:
        raise ValueError(message)


def integer(value, low, high, name):
    require(type(value) is int and low <= value <= high, f'{name} must be an integer from {low} to {high}')
    return value


def positive(value):
    require(type(value) in (float, int) and math.isfinite(value) and value > 0, 'Quantity must be finite and positive')
    return value


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False), encoding='ascii')


class Cancelled(Exception):
    pass


class Application:
    def __init__(self, executable):
        self.executable = Path(executable).resolve()
        require(self.executable.is_file(), 'Configured executable does not exist')
        manifest = cal.read_json(self.executable.parent/'local-app-build.json')
        require(manifest['configuration'] == 'Release' and manifest['source_sha256'] == source_hash()
                and manifest['executable_sha256'] == cal.digest(self.executable),
                'Executable/source build fingerprint mismatch; run the default startup command to rebuild')
        self.build = manifest
        self.identity = {'sha256': cal.digest(self.executable), 'source_sha256': source_hash(), 'configuration': 'Release',
                         'adapter_sha256': cal.digest(__file__), 'calibrator_sha256': cal.digest(cal.__file__),
                         'calendar_sha256': cal.digest(CALENDAR)}
        self.lock = threading.RLock()
        self.active = None
        self.jobs = {}
        self.datasets = {}
        self.home = ROOT/'data/local/browser-app'
        self.home.mkdir(parents=True, exist_ok=True)
        self.session = self.home/secrets.token_hex(12)
        self.session.mkdir()
        self.capabilities = {}
        for backend in ('serial', 'openmp', 'cuda'):
            try:
                argv = [str(self.executable), '8', '42', '--backend', backend]
                if backend == 'openmp':
                    argv += ['--threads', '1']
                value = self.process(argv+['--json'], None)
                json.loads(value)
                self.capabilities[backend] = {'available': True, 'reason': 'Startup execution probe passed'}
            except Exception as exc:
                self.capabilities[backend] = {'available': False, 'reason': str(exc)}
        require(self.capabilities['serial']['available'], 'Serial executable probe failed')

    def process(self, argv, job, raw=False):
        if job and job['cancel'].is_set():
            raise Cancelled()
        process = subprocess.Popen(argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0,
                                   start_new_session=os.name != 'nt')
        with self.lock:
            if job:
                job['process'] = process
        deadline = time.monotonic()+TIMEOUT
        try:
            while True:
                if job and job['cancel'].is_set():
                    raise Cancelled()
                if time.monotonic() > deadline or (job and time.monotonic()-job['started'] > 180):
                    raise ValueError(f'Child process exceeded {TIMEOUT} seconds')
                try:
                    stdout, stderr = process.communicate(timeout=.1)
                    break
                except subprocess.TimeoutExpired:
                    continue
            require(process.returncode == 0, 'Child process failed: '+stderr.decode('utf-8', errors='replace')[-4000:])
            if job and job['cancel'].is_set():
                raise Cancelled()
            return stdout if raw else stdout.decode('utf-8-sig')
        finally:
            try:
                if process.poll() is None:
                    try:
                        if os.name == 'nt':
                            subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                        else:
                            import signal
                            os.killpg(process.pid, signal.SIGKILL)
                    finally:
                        if process.poll() is None:
                            process.kill()
                process.communicate(timeout=10)
            finally:
                with self.lock:
                    if job:
                        job['process'] = None

    def submit(self, kind, payload):
        with self.lock:
            require(self.active is None, 'Another operation is running; wait or cancel it')
            require(len(self.jobs) < 60, 'Session job limit reached; restart the application')
            require(sum(p.stat().st_size for p in self.home.rglob('*') if p.is_file()) + MAX_BODY < DISK_LIMIT,
                    'Local storage limit reached (512 MiB); archive or remove app-owned session folders')
            job = {'id': secrets.token_hex(12), 'state': 'running', 'kind': kind, 'cancel': threading.Event(),
                   'process': None, 'results': [], 'started': time.monotonic(), 'error': None}
            self.active = job
            self.jobs[job['id']] = job
            threading.Thread(target=self.work, args=(job, payload), daemon=True).start()
            return self.snapshot(job)

    def work(self, job, payload):
        try:
            if job['kind'] == 'validate':
                result = self.validate_data(payload, job)
                with self.lock:
                    if job['cancel'].is_set():
                        raise Cancelled()
                    self.datasets[job['id']] = result
                    job['dataset'] = result['public']
            else:
                self.analyze(payload, job)
            with self.lock:
                if job['cancel'].is_set():
                    raise Cancelled()
                job['state'] = 'completed'
        except Cancelled:
            with self.lock:
                job['state'] = 'cancelled'
        except Exception as exc:
            with self.lock:
                job['state'] = 'failed'
                job['error'] = str(exc)
        finally:
            with self.lock:
                job['elapsed_ms'] = (time.monotonic()-job['started'])*1000
                try:
                    write_json(self.session/(job['id']+'-job.json'), self.snapshot(job))
                except OSError as exc:
                    job['state'] = 'failed'
                    job['error'] = 'Cannot save local job record: '+str(exc)
                finally:
                    self.active = None

    def snapshot(self, job):
        with self.lock:
            return {k: v for k, v in job.items() if k not in ('cancel', 'process', 'started')} | {
                'elapsed_ms': job.get('elapsed_ms', (time.monotonic()-job['started'])*1000)}

    def cancel(self, ident):
        with self.lock:
            job = self.jobs[ident]
            if job['state'] == 'running':
                job['cancel'].set()
            return self.snapshot(job)

    def validate_data(self, payload, job):
        require(len(self.datasets) < 12, 'Dataset limit reached; restart the application')
        if 'example' in payload:
            require(payload['example'] in ('single', 'portfolio'), 'Unknown example')
            payload = cal.read_json(Path(__file__).parent/'examples'/('request-'+payload['example']+'.json'))
            for item in payload['assets']:
                for key in ('csv', 'metadata'):
                    item[key] = base64.b64encode((Path(__file__).parent/'examples'/item[key]).read_bytes()).decode('ascii')
        require(payload.get('calendar') == 'nasdaq-2023-2025', 'Select the supported Nasdaq 2023..2025 calendar')
        start, end = payload.get('start'), payload.get('end')
        expected = cal.sessions(cal.read_json(CALENDAR), cal.date(start), cal.date(end))
        assets = payload.get('assets')
        require(isinstance(assets, list) and 1 <= len(assets) <= 5, 'Supply 1..5 assets')
        folder = self.session/job['id']
        folder.mkdir()
        imports, previews, declarations = [], [], []
        for i, item in enumerate(assets):
            require(item.get('format') in ('existing_csv', 'kibot_daily'), 'Unsupported file format')
            quantity = positive(item.get('quantity'))
            source = folder/str(i)
            source.mkdir()
            for key, filename in (('csv', 'upload.csv'), ('metadata', 'metadata.json')):
                try:
                    data = base64.b64decode(item[key], validate=True)
                except (ValueError, KeyError, binascii.Error) as exc:
                    raise ValueError('CSV and metadata files are both required') from exc
                require(0 < len(data) <= MAX_FILE, 'Each upload must be 1 byte..1 MiB')
                (source/filename).write_bytes(data)
            metadata = cal.read_json(source/'metadata.json')
            for key in ('currency_basis_url', 'close_definition'):
                require(isinstance(metadata.get(key), str) and metadata[key].strip(), 'Missing metadata: '+key)
            imported = source/'import'
            self.process(['powershell.exe', '-NoProfile', '-File', str(ROOT/'scripts/import-equity-data.ps1'),
                          '-InputFile', str(source/'upload.csv'), '-MetadataFile', str(source/'metadata.json'),
                          '-OutputDirectory', str(imported), '-RequestedStart', start, '-RequestedEnd', end,
                          '-SourceFormat', item['format']], job)
            rows = cal.prices(imported/'prices.csv')
            require([d for d, p in rows] == expected,
                    'Missing/unexpected Nasdaq sessions; no filling, intersection or reordering is allowed')
            declarations.append(metadata)
            imports.append({'import': str(imported), 'quantity': quantity})
            previews.append({'symbol': metadata['symbol'], 'quantity': quantity, 'rows': rows,
                             'manifest': cal.read_json(imported/'manifest.json')})
        require(len({m['symbol'] for m in declarations}) == len(declarations), 'Duplicate asset identity')
        for key in ('currency', 'source_name', 'price_adjustment_policy', 'close_definition', 'data_kind'):
            require(len({m[key] for m in declarations}) == 1, 'Incompatible '+key)
        public = {'id': job['id'], 'unit': declarations[0]['currency'], 'assets': previews,
                  'start': start, 'end': end, 'calendar': 'nasdaq-2023-2025',
                  'calendar_sha256': cal.digest(CALENDAR),
                  'provenance_status': 'User declarations; not independently authenticated. Calendar sequence and exact-byte hashes checked locally.',
                  'declarations': declarations}
        return {'public': public, 'imports': imports, 'folder': folder}

    def analyze(self, payload, job):
        dataset = self.datasets.get(payload.get('dataset'))
        require(dataset is not None, 'Validate a dataset first')
        n = integer(payload.get('scenarios'), 1, 10000000, 'Scenarios')
        seed = payload.get('seed')
        require(isinstance(seed, str) and re.fullmatch('[0-9]{1,20}', seed) and int(seed) <= 2**64-1,
                'Seed must be an unsigned 64-bit integer')
        horizon = integer(payload.get('horizon_days'), 1, 2520, 'Horizon trading days')
        configs = payload.get('engines')
        require(isinstance(configs, list) and 1 <= len(configs) <= 4, 'Select 1..4 engine configurations')
        options = []
        for config in configs:
            require(isinstance(config, dict), 'Invalid engine configuration')
            backend = config.get('backend')
            require(backend in self.capabilities and self.capabilities[backend]['available'], 'Selected backend is unavailable')
            args = ['--backend', backend]
            allowed = {'backend'}
            if backend == 'openmp':
                allowed.add('threads')
                threads = integer(config.get('threads'), 1, min(32, os.cpu_count() or 1), 'OpenMP threads')
                args += ['--threads', str(threads)]
            if backend == 'cuda':
                allowed.add('mode')
                mode = config.get('mode')
                require(mode in ('full-device', 'hybrid'), 'Select a CUDA mode explicitly')
                args += ['--cuda-mode', mode]
                if mode == 'hybrid':
                    allowed.add('batch_size')
                    args += ['--batch-size', str(integer(config.get('batch_size'), 1, 10000000, 'CUDA batch size'))]
            require(set(config) <= allowed, 'Incompatible engine options')
            options.append(args)
        require(cal.digest(CALENDAR) == dataset['public']['calendar_sha256'], 'Calendar changed; validate data again')
        for preview, item in zip(dataset['public']['assets'], dataset['imports']):
            for name, key in (('raw.csv', 'raw_sha256'), ('source-metadata.json', 'source_metadata_sha256'),
                              ('prices.csv', 'converted_sha256')):
                require(cal.digest(Path(item['import'])/name) == preview['manifest'][key],
                        'Stored import hash mismatch; validate original files again')
        folder = self.session/job['id']
        folder.mkdir()
        request = {'start': dataset['public']['start'], 'end': dataset['public']['end'], 'calendar': str(CALENDAR),
                   'frequency': 'daily', 'days_per_year': 252, 'horizon_days': horizon, 'assets': dataset['imports']}
        write_json(folder/'calibration-request.json', request)
        if len(request['assets']) == 1:
            item = request['assets'][0]
            prefix = ['--csv', str(Path(item['import'])/'prices.csv'), str(n), seed, str(horizon), '252',
                      '--quantity', str(item['quantity'])]
        else:
            calibration, text = cal.calibrate(folder/'calibration-request.json')
            (folder/'portfolio.txt').write_text(text, encoding='ascii')
            write_json(folder/'calibration.json', calibration)
            prefix = ['--portfolio', str(folder/'portfolio.txt'), str(n), seed]
        write_json(folder/'settings.json', payload)
        for index, args in enumerate(options):
            output = self.process([str(self.executable)]+prefix+args+['--json'], job, raw=True)
            (folder/('engine-'+str(index)+'.json')).write_bytes(output)
            result = json.loads(output)
            with self.lock:
                job['results'].append(result)
        job['settings'] = payload
        job['provenance'] = dataset['public']
        job['build'] = self.identity
        job['timing_notice'] = 'Fresh child process per engine; engine wall time excludes calibration and output. Application elapsed includes validation of settings, calibration, process startup and sequential runs. Illustrative, not a formal benchmark or statistical acceptance.'


class Server(ThreadingHTTPServer):
    daemon_threads = True
    # Bound even slow HTTP clients; one active analysis/validation worker.
    def __init__(self, address, app):
        self.app = app
        self.slots = threading.BoundedSemaphore(12)
        super().__init__(address, Handler)
    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        super().process_request(request, address)
    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def log_message(self, *args):
        pass
    def reply(self, status, value, mime='application/json', download=None):
        data = json.dumps(value, allow_nan=False).encode('ascii') if mime == 'application/json' else value
        self.send_response(status)
        for key, val in {'Content-Type': mime, 'Content-Length': str(len(data)), 'Cache-Control': 'no-store',
                         'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer',
                         'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; form-action 'none'; base-uri 'none'"}.items():
            self.send_header(key, val)
        if download:
            self.send_header('Content-Disposition', 'attachment; filename="'+download+'"')
        self.end_headers()
        self.wfile.write(data)
    def check(self, post=False):
        port = self.server.server_port
        allowed = (f'127.0.0.1:{port}', f'localhost:{port}')
        require(self.headers.get('Host') in allowed, 'Invalid Host')
        origin = self.headers.get('Origin')
        require(origin is None and not post or origin in ['http://'+h for h in allowed], 'Invalid Origin')
        require(self.headers.get('Sec-Fetch-Site') not in ('cross-site',), 'Cross-site access denied')
    def do_GET(self):
        try:
            self.check()
            app = self.server.app
            if self.path == '/api/info':
                self.reply(200, {'engines': app.capabilities, 'max_threads': min(32, os.cpu_count() or 1),
                                 'max_file_bytes': MAX_FILE, 'build': app.identity})
            elif self.path.startswith('/api/jobs/'):
                parts = self.path.split('/')
                job = app.jobs[parts[3]]
                result = app.snapshot(job)
                if len(parts) == 5:
                    require(result['state'] == 'completed' and result['kind'] == 'run', 'Completed result required')
                    require(parts[4] in ('json', 'csv'), 'Unknown download format')
                    if parts[4] == 'json':
                        self.reply(200, result, download='analysis.json')
                    else:
                        out = io.StringIO(newline='')
                        writer = csv.writer(out)
                        writer.writerow(['backend', 'mode', 'confidence', 'mc_var', 'analytical_var', 'V0', 'unit', 'N', 'seed', 'engine_ms', 'application_ms', 'settings_json', 'provenance_json', 'build_json'])
                        for r in result['results']:
                            for e in r['estimates']:
                                writer.writerow([r['backend'], (r['cuda'] or {}).get('mode', ''), e['confidence'], e['mc_var'],
                                                 e['analytical_var'], (r.get('portfolio') or r['model'])['initial_value'],
                                                 result['provenance']['unit'], r['scenarios'], r['seed'], r['end_to_end_ms'],
                                                 result['elapsed_ms'], json.dumps(result['settings']), json.dumps(result['provenance']), json.dumps(result['build'])])
                        self.reply(200, out.getvalue().encode('ascii'), 'text/csv', 'analysis.csv')
                else:
                    require(len(parts) == 4, 'Unknown endpoint')
                    self.reply(200, result)
            else:
                files = {'/': ('index.html', 'text/html'), '/app.js': ('app.js', 'text/javascript'), '/style.css': ('style.css', 'text/css')}
                require(self.path in files, 'Unknown page')
                name, mime = files[self.path]
                self.reply(200, (STATIC/name).read_bytes(), mime)
        except (ValueError, KeyError) as exc:
            self.reply(400, {'error': str(exc)})
        except (ConnectionError, socket.timeout):
            pass
    def do_POST(self):
        try:
            self.check(post=True)
            require(self.headers.get('Content-Type') == 'application/json', 'Expected application/json')
            require(not self.headers.get('Transfer-Encoding'), 'Chunked uploads unsupported')
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= MAX_BODY:
                self.reply(413, {'error': 'Request exceeds 8 MiB or is empty'})
                self.close_connection = True
                return
            body = self.rfile.read(size)
            require(len(body) == size, 'Incomplete request')
            payload = json.loads(body, parse_constant=lambda _: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))
            require(isinstance(payload, dict), 'Expected JSON object')
            app = self.server.app
            if self.path == '/api/data':
                self.reply(202, app.submit('validate', payload))
            elif self.path == '/api/run':
                self.reply(202, app.submit('run', payload))
            elif re.fullmatch('/api/jobs/[a-f0-9]{24}/cancel', self.path):
                self.reply(200, app.cancel(self.path.split('/')[3]))
            else:
                raise ValueError('Unknown endpoint')
        except (ValueError, KeyError, TypeError) as exc:
            self.reply(400, {'error': str(exc)})
        except (ConnectionError, socket.timeout):
            pass


def serve(executable, port=8765):
    integer(port, 1024, 65535, 'Port')
    app = Application(executable)
    server = Server(('127.0.0.1', port), app)
    print(f'Local Monte Carlo Lab: http://127.0.0.1:{port}', flush=True)
    print('Local files only. Ctrl+C stops the service and cancels its active child.', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        with app.lock:
            active = app.active
            if active:
                active['cancel'].set()
        deadline = time.monotonic()+15
        while app.active and time.monotonic() < deadline:
            time.sleep(.05)
        server.server_close()
