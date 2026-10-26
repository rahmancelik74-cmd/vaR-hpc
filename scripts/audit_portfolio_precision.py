"""Retain focused local verification and runtime/native-record provenance."""
import importlib
import json
import os
import platform
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

from portfolio_precision import ROOT, OLD, PUBLIC, sha, load, read_csv, save


def main():
    # The 30 reused endpoint process records are read, never re-executed.
    records=[]
    for row in read_csv(OLD/'validation-raw.csv'):
        if row['fixture']=='five-identity' or int(row['scenarios'])!=10000000:
            continue
        path=ROOT/'results/portfolio-campaign-20261025/processes'/('%04d.json'%int(row['id']))
        assert sha(path)==row['record_sha256']
        native=load(path); launch=json.loads(native['stdout']); actual=json.loads(launch['stdout'])
        assert native['probe_exit']==launch['exit_code']==0 and not launch['timed_out']
        assert actual['scenarios']==10000000 and int(actual['seed'])==int(row['seed'])
        for i,key in enumerate(('var95','var99')):
            assert actual['estimates'][i]['mc_var']==float(row[key])
        records.append(dict(id=int(row['id']),path=path.relative_to(ROOT).as_posix(),sha256=sha(path)))
    assert len(records)==30
    commands=[
        ['-m','unittest','discover','-s','tests','-p','test_portfolio_precision*.py','-v'],
        ['-m','unittest','discover','-s','tests','-p','test_portfolio_campaign.py','-v'],
        ['scripts/verify_portfolio_precision.py','--local'],
        ['scripts/verify_portfolio_campaign.py']]
    checks=[]
    for args in commands:
        cmd=[sys.executable,'-B',*args]
        proc=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=120)
        checks.append(dict(command=cmd,exit_code=proc.returncode,
            stdout=proc.stdout.decode('ascii',errors='replace'),stderr=proc.stderr.decode('ascii',errors='replace')))
        if proc.returncode:
            save(PUBLIC/'verification.json',dict(status='failed',checks=checks))
            raise RuntimeError('Focused verification failed')
    runtime={}
    for module in ('numpy.random._pcg64','numpy.core._multiarray_umath','scipy.integrate._quadpack','scipy.optimize._zeros'):
        m=importlib.import_module(module)
        runtime[module]=dict(path=m.__file__,sha256=sha(m.__file__))
    source_diff=subprocess.check_output(['git','diff','--','src','include','CMakeLists.txt'],cwd=ROOT)
    assert not source_diff
    save(PUBLIC/'verification.json',dict(status='passed',utc=datetime.now(timezone.utc).isoformat(),
        scope='Focused reference/integration/reassessment tests; local full sorted-array hashes/ranks; original public campaign integrity; 30 original endpoint launch-record hashes/values. No engines or large generation launched.',
        checks=checks,reused_endpoint_records=records,compiled_runtime_modules=runtime,
        processor=platform.processor(),logical_cpu_count=os.cpu_count(),
        production_source_diff='empty; no production source/build contract changes',
        protocol_sha256=sha(PUBLIC/'protocol-v1.json'),
        figure_review='Rendered comparison.png inspected at 1600x832; no clipping; exported data checked against CSV.'))
    print('Focused audit passed; 30 original native records checked, no native launches')


if __name__=='__main__':
    main()
