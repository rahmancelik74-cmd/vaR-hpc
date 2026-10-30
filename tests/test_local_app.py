"""Local browser adapter regressions; only artificial public inputs are used."""
import base64
import csv
import io
import http.client
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from local_app.server import Application, MAX_BODY, Server, source_hash
from local_app import server as module


def example(count=1):
    p = ROOT/'local_app/examples'
    value = json.loads((p/('request-single.json' if count == 1 else 'request-portfolio.json')).read_text())
    for item in value['assets']:
        for key in ('csv', 'metadata'):
            item[key] = base64.b64encode((p/item[key]).read_bytes()).decode('ascii')
    return value


class LocalAppContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        executable = os.environ.get('MC_LOCAL_APP_EXE')
        if not executable:
            raise unittest.SkipTest('Set MC_LOCAL_APP_EXE to a current Release build for integration tests')
        cls.exe = Path(executable).resolve()
        (cls.exe.parent/'local-app-build.json').write_text(json.dumps(dict(configuration='Release', source_sha256=source_hash(), executable_sha256=module.cal.digest(cls.exe))))
        cls.app = Application(cls.exe)
        cls.server = Server(('127.0.0.1', 0), cls.app)
        cls.port = cls.server.server_port
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def request(self, path, body=None, origin=None, host=None, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=15)
        h = {'Host': host or f'127.0.0.1:{self.port}'}
        if body is not None:
            h.update({'Origin': origin or f'http://127.0.0.1:{self.port}', 'Content-Type': 'application/json'})
        h.update(headers or {})
        connection.request('GET' if body is None else 'POST', path, None if body is None else json.dumps(body), h)
        response = connection.getresponse()
        status, data = response.status, response.read()
        connection.close()
        return status, data

    def job(self, path, payload):
        status, body = self.request(path, payload)
        self.assertEqual(status, 202, body)
        job = json.loads(body)
        limit = time.monotonic()+40
        while time.monotonic() < limit:
            _, body = self.request('/api/jobs/'+job['id'])
            job = json.loads(body)
            if job['state'] != 'running':
                # Wait for worker's final record and active-slot release.
                while self.app.active is not None and time.monotonic() < limit:
                    time.sleep(.01)
                return json.loads(self.request('/api/jobs/'+job['id'])[1])
            time.sleep(.02)
        self.fail('Job failed to terminate')

    def settings(self, dataset):
        return dict(dataset=dataset, scenarios=10003, seed='18446744073709551615', horizon_days=10, engines=[{'backend':'serial'}])

    def test_host_origin_and_upload_limits(self):
        self.assertEqual(self.request('/api/info', host='attacker.invalid')[0], 400)
        self.assertEqual(self.request('/api/run', {}, origin='http://attacker.invalid')[0], 400)
        self.assertEqual(self.request('/api/run', {}, headers={'Content-Length': str(MAX_BODY+1)})[0], 413)
        self.assertEqual(self.request('/../../AGENTS.md')[0], 400)
        payload = example()
        payload['assets'][0]['csv'] = base64.b64encode(b'x'*(1024*1024+1)).decode()
        if os.name == 'nt':
            job = self.job('/api/data', payload)
            self.assertEqual(job['state'], 'failed')
            self.assertIn('1 MiB', job['error'])

    def test_invalid_settings_and_unavailable_backend(self):
        # Invalid datasets cannot reach a child process.
        job = self.job('/api/run', self.settings('unknown'))
        self.assertEqual(job['state'], 'failed')
        self.assertEqual(self.request('/api/jobs/'+job['id']+'/json')[0], 400)
        self.app.datasets['test-settings'] = {'public':{}, 'imports':[]}
        try:
            for change in ({'scenarios':0}, {'seed':'18446744073709551616'}, {'horizon_days':0},
                           {'engines':[{'backend':'serial','threads':2}]}, {'engines':[{'backend':'cuda','mode':'hybrid'}]}):
                request = self.settings('test-settings') | change
                self.assertEqual(self.job('/api/run',request)['state'], 'failed')
            saved = self.app.capabilities['cuda']
            self.app.capabilities['cuda'] = {'available':False}
            try:
                j = self.job('/api/run',self.settings('test-settings') | {'engines':[{'backend':'cuda','mode':'full-device'}]})
                self.assertIn('unavailable',j['error'])
            finally:
                self.app.capabilities['cuda'] = saved
        finally:
            del self.app.datasets['test-settings']

    def test_process_failure_timeout_and_cancellation(self):
        with self.assertRaisesRegex(ValueError, 'Engine execution failed'):
            self.app.process([str(self.exe), '--invalid-option'], None)
        with patch.object(module, 'TIMEOUT', .1):
            with self.assertRaisesRegex(ValueError, 'exceeded'):
                self.app.process([sys.executable, '-c', 'import time; time.sleep(20)'], None)
        payload = self.settings('unused')
        original = self.app.analyze
        def slow(request, job):
            self.app.process([sys.executable, '-c', 'import time; time.sleep(20)'], job)
        self.app.analyze = slow
        try:
            status, body = self.request('/api/run', payload)
            self.assertEqual(status, 202)
            ident = json.loads(body)['id']
            self.assertEqual(self.request('/api/run', payload)[0], 400)
            self.request('/api/jobs/'+ident+'/cancel', {})
            deadline = time.monotonic()+10
            while self.app.active and time.monotonic() < deadline:
                time.sleep(.02)
            job = json.loads(self.request('/api/jobs/'+ident)[1])
            self.assertEqual(job['state'], 'cancelled')
            self.assertIsNone(self.app.active)
            self.assertEqual(self.request('/api/jobs/'+ident+'/json')[0], 400)
        finally:
            self.app.analyze = original

    @unittest.skipUnless(os.name == 'nt', 'Existing importer requires Windows PowerShell')
    def test_malformed_files_metadata_calendar_and_sessions(self):
        cases = []
        p = example(); p.pop('calendar'); cases.append((p,'calendar'))
        p = example(); p['end'] = '2026-01-08'; cases.append((p,'coverage'))
        p = example(); p['assets'][0].pop('metadata'); cases.append((p,'metadata'))
        p = example(); p['assets'][0]['metadata'] = base64.b64encode(b'{}').decode(); cases.append((p,'metadata'))
        p = example(); p['assets'][0]['format'] = 'xlsx'; cases.append((p,'format'))
        for raw in (b'date,close\n2024-01-02,100\n2024-01-02,101\n2024-01-03,102\n',
                    b'date,close\n2024-01-03,100\n2024-01-02,101\n2024-01-04,102\n',
                    b'date,close\n2024-01-02,100\n2024-01-03,101\n2024-01-08,102\n',
                    b'date,close\n2024-01-02,NaN\n2024-01-03,101\n2024-01-04,102\n'):
            p = example(); p['assets'][0]['csv'] = base64.b64encode(raw).decode(); cases.append((p,''))
        for p, message in cases:
            with self.subTest(message=message):
                job = self.job('/api/data',p)
                self.assertEqual(job['state'],'failed',job)
                self.assertIn(message.lower(),job['error'].lower())

    @unittest.skipUnless(os.name == 'nt', 'Existing importer requires Windows PowerShell')
    def test_real_single_and_portfolio_round_trip(self):
        for count in (1,2):
            dataset = self.job('/api/data', example(count))
            self.assertEqual(dataset['state'],'completed',dataset)
            request = self.settings(dataset['id'])
            request['engines'] += [{'backend':'openmp','threads':1}] if self.app.capabilities['openmp']['available'] else []
            if self.app.capabilities['cuda']['available']:
                request['engines'] += [{'backend':'cuda','mode':'full-device'}, {'backend':'cuda','mode':'hybrid','batch_size':257}]
            job = self.job('/api/run', request)
            self.assertEqual(job['state'],'completed',job)
            folder = self.app.session/job['id']
            for config, actual in zip(request['engines'], job['results']):
                if count == 1:
                    prices = Path(self.app.datasets[dataset['id']]['imports'][0]['import'])/'prices.csv'
                    prefix = ['--csv', str(prices), '10003', request['seed'], '10','252','--quantity','1']
                else:
                    prefix = ['--portfolio',str(folder/'portfolio.txt'),'10003',request['seed']]
                args = ['--backend',config['backend']]
                if config['backend']=='openmp': args += ['--threads','1']
                if config['backend']=='cuda':
                    args += ['--cuda-mode',config['mode']]
                    if config['mode']=='hybrid': args += ['--batch-size','257']
                direct = json.loads(subprocess.check_output([str(self.exe)]+prefix+args+['--json']))
                for key in ('estimates','model','portfolio','seed','scenarios','backend','calibration'):
                    self.assertEqual(actual.get(key),direct.get(key),key)
                if config.get('mode') == 'hybrid' and count == 2:
                    self.assertEqual(actual['cuda']['mode'], 'hybrid')
                    self.assertEqual(actual['cuda']['requested_batch_size'], 257)
                    self.assertEqual(actual['cuda']['effective_batch_size'], 257)
                    self.assertEqual(actual['cuda']['batch_count'], 39)
                    self.assertEqual(actual['scenarios'] % 257, 237)
            for extension in ('json','csv'):
                status, data = self.request('/api/jobs/'+job['id']+'/'+extension)
                self.assertEqual(status,200)
                self.assertIn(b'provenance',data)
                if extension == 'json':
                    downloaded = json.loads(data)
                    self.assertEqual(downloaded['settings'], request)
                    self.assertEqual(downloaded['results'], job['results'])
                else:
                    rows = list(csv.DictReader(io.StringIO(data.decode('ascii'))))
                    expected = [(r, e) for r in job['results'] for e in r['estimates']]
                    self.assertEqual(len(rows), len(expected))
                    for row, (result, estimate) in zip(rows, expected):
                        self.assertEqual(json.loads(row['settings_json']), request)
                        self.assertEqual(float(row['mc_var']), estimate['mc_var'])
                        self.assertEqual(float(row['engine_ms']), result['end_to_end_ms'])
                        self.assertEqual(row['seed'], request['seed'])
                        self.assertEqual(int(row['N']), request['scenarios'])
            if count == 1:
                direct2=json.loads(subprocess.check_output([str(self.exe),'--csv',str(prices),'10003',request['seed'],'10','252','--quantity','2','--json']))
                self.assertEqual(direct2['model']['initial_value'],2*job['results'][0]['model']['initial_value'])
                for doubled, single in zip(direct2['estimates'],job['results'][0]['estimates']):
                    self.assertEqual(doubled['mc_var'],2*single['mc_var'])
                cancellation = self.settings(dataset['id']) | {'scenarios':10000000}
                status, body = self.request('/api/run', cancellation)
                self.assertEqual(status,202)
                ident = json.loads(body)['id']
                deadline = time.monotonic()+5
                child = None
                while time.monotonic() < deadline:
                    with self.app.lock:
                        child = self.app.jobs[ident]['process']
                    if child is not None:
                        break
                    time.sleep(.001)
                self.assertIsNotNone(child)
                self.request('/api/jobs/'+ident+'/cancel',{})
                while self.app.active and time.monotonic() < deadline:
                    time.sleep(.01)
                cancelled = json.loads(self.request('/api/jobs/'+ident)[1])
                self.assertEqual(cancelled['state'],'cancelled')
                self.assertIsNotNone(child.poll())
            else:
                self.assertIsNone(job['results'][0]['estimates'][0]['analytical_var'])

    def test_quantity_cli_rejections(self):
        for args in (['--quantity','2'], ['--csv', str(ROOT/'data/synthetic_prices.csv'),'--quantity','nan'],
                     ['--csv',str(ROOT/'data/synthetic_prices.csv'),'--quantity','0'],
                     ['--csv',str(ROOT/'data/synthetic_prices.csv'),'--quantity','2','--quantity','2']):
            self.assertNotEqual(subprocess.run([str(self.exe)]+args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode,0)


if __name__ == '__main__':
    unittest.main()
