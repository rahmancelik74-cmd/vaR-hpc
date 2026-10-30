"""Focused public-error/private-diagnostic boundary checks; artificial inputs only."""
import base64
import json
import os
import sys
import unittest
import threading
import time
import test_local_app as base
example = base.example
from local_app import server as module


class ErrorPresentationTests(base.LocalAppContract):
    # Use the existing real HTTP fixture without repeating its unrelated scenarios.
    test_host_origin_and_upload_limits = None
    test_invalid_settings_and_unavailable_backend = None
    test_malformed_files_metadata_calendar_and_sessions = None
    test_process_failure_timeout_and_cancellation = None
    test_quantity_cli_rejections = None
    test_real_single_and_portfolio_round_trip = None

    @unittest.skipUnless(os.name == 'nt', 'Real importer requires Windows PowerShell')
    def test_expected_errors_and_recovery(self):
        few = example(); few['assets'][0]['csv'] = base64.b64encode(b'date,close\n2024-01-02,100\n').decode()
        numeric = example(); raw = base64.b64decode(numeric['assets'][0]['csv']).replace(b',101', b',bad', 1)
        numeric['assets'][0]['csv'] = base64.b64encode(raw).decode()
        missing = example(); raw = base64.b64decode(missing['assets'][0]['csv'])
        missing['assets'][0]['csv'] = base64.b64encode(b'\n'.join(x for x in raw.split(b'\n') if not x.startswith(b'2024-01-04'))).decode()
        metadata = example(); m = json.loads(base64.b64decode(metadata['assets'][0]['metadata'])); del m['source_name']
        metadata['assets'][0]['metadata'] = base64.b64encode(json.dumps(m).encode()).decode()
        for payload, code, phrase in [(few,'too_few_observations','at least three'),(numeric,'invalid_number','invalid number'),
                                      (missing,'invalid_input','expected trading session'),(metadata,'invalid_metadata','metadata')]:
            with self.subTest(code=code):
                failed = self.job('/api/data',payload)
                self.assertEqual(failed['state'],'failed')
                self.assertEqual(failed['error_code'],code)
                self.assertIn(phrase,failed['error'])
                self.assertLess(len(failed['error']),250)
                self.assertEqual(failed['results'],[])
                for forbidden in ('CategoryInfo','FullyQualifiedErrorId','At C:',str(module.ROOT),'.ps1', 'Traceback'):
                    self.assertNotIn(forbidden,json.dumps(failed))
                self.assertEqual(self.request('/api/jobs/'+failed['id']+'/json')[0],400)
                if code != 'invalid_input':
                    record = self.app.session/failed['id']
                    stderr = list(record.glob('*.stderr.bin'))
                    self.assertTrue(stderr)
                    # The importer explicitly selects UTF-8 in its own child process.
                    decoded = stderr[0].read_bytes().decode('utf-8',errors='strict')
                    self.assertIn('equity-data-common.ps1',decoded)
                    self.assertNotIn('\ufffd',decoded)
                    self.assertEqual(self.request('/'+stderr[0].relative_to(module.ROOT).as_posix())[0],400)
                valid = self.job('/api/data',example())
                result = self.job('/api/run',self.settings(valid['id']) | {'scenarios':100})
                self.assertEqual(result['state'],'completed')

    def test_unknown_process_diagnostics_are_exact_private_bytes(self):
        original = self.app.analyze
        raw = b'unknown internal detail C:\\private\\file.ps1\r\n\xff\x00'
        def fail(payload, job):
            self.app.process([sys.executable,'-c',f'import sys; sys.stderr.buffer.write({raw!r}); sys.exit(7)'],job)
        self.app.analyze = fail
        try:
            failed = self.job('/api/run',{})
            self.assertEqual(failed['state'],'failed')
            self.assertIn('Engine execution failed',failed['error'])
            self.assertIn('cause could not be determined',failed['error'])
            self.assertNotIn('unknown internal detail',json.dumps(failed))
            stderr = list((self.app.session/failed['id']).glob('*.stderr.bin'))
            self.assertEqual(stderr[0].read_bytes(),raw)
            self.assertEqual(self.request('/api/jobs/'+failed['id']+'/csv')[0],400)
        finally:
            self.app.analyze = original
        if os.name == 'nt':
            valid = self.job('/api/data',example())
            result = self.job('/api/run',self.settings(valid['id']) | {'scenarios':100})
            self.assertEqual(result['state'],'completed')

    @unittest.skipUnless(os.name == 'nt','Windows redirected encoding check')
    def test_importer_unicode_path_encoding_and_exact_capture(self):
        # Compare raw bytes from a real child to its stored bytes, without normalization.
        job = {'id':'encoding-'+os.urandom(5).hex(),'cancel':threading.Event(),'started':time.monotonic()}
        script = self.app.session/(job['id']+'.ps1')
        script.write_text("[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)\n[Console]::Error.Write('path-'+[char]0xFC+'-'+[char]0x131)\nexit 1\n",encoding='ascii')
        with self.assertRaises(module.ProcessFailure):
            self.app.process(['powershell.exe','-NoProfile','-File',str(script)],job,error_report=self.app.session/'not-created.json')
        raw = next((self.app.session/job['id']).glob('*.stderr.bin')).read_bytes()
        self.assertEqual(raw, 'path-\u00fc-\u0131'.encode('utf-8'))
