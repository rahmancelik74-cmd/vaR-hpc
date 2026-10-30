"""Exercise the actual extracted portable CPU ZIP under a restricted environment."""
import argparse
import base64
import csv
import ctypes
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[1]


class ProcessEntry(ctypes.Structure):
    _fields_=[('dwSize',ctypes.c_ulong),('cntUsage',ctypes.c_ulong),('th32ProcessID',ctypes.c_ulong),
              ('th32DefaultHeapID',ctypes.c_size_t),('th32ModuleID',ctypes.c_ulong),('cntThreads',ctypes.c_ulong),
              ('th32ParentProcessID',ctypes.c_ulong),('pcPriClassBase',ctypes.c_long),('dwFlags',ctypes.c_ulong),
              ('szExeFile',ctypes.c_wchar*260)]


def engine_children(pid):
    k=ctypes.WinDLL('kernel32',use_last_error=True)
    k.CreateToolhelp32Snapshot.restype=ctypes.c_void_p
    k.Process32FirstW.argtypes=[ctypes.c_void_p,ctypes.POINTER(ProcessEntry)]
    k.Process32NextW.argtypes=[ctypes.c_void_p,ctypes.POINTER(ProcessEntry)]
    k.CloseHandle.argtypes=[ctypes.c_void_p]
    snapshot=k.CreateToolhelp32Snapshot(2,0)
    entry=ProcessEntry();entry.dwSize=ctypes.sizeof(entry);children=[]
    try:
        ok=k.Process32FirstW(snapshot,ctypes.byref(entry))
        while ok:
            if entry.th32ParentProcessID==pid and entry.szExeFile.lower()=='mc_var.exe':children.append(entry.th32ProcessID)
            ok=k.Process32NextW(snapshot,ctypes.byref(entry))
    finally:k.CloseHandle(snapshot)
    return children


def assert_exited(pids):
    k=ctypes.WinDLL('kernel32',use_last_error=True)
    k.OpenProcess.restype=ctypes.c_void_p
    k.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
    k.CloseHandle.argtypes=[ctypes.c_void_p]
    for pid in pids:
        handle=k.OpenProcess(0x100000,False,pid)
        if handle:
            try:assert k.WaitForSingleObject(handle,5000)==0,('Owned process survived',pid)
            finally:k.CloseHandle(handle)
        else:
            assert ctypes.get_last_error()==87,('Cannot inspect owned process',pid,ctypes.get_last_error())


def wait_for(predicate,timeout=30):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        result=predicate()
        if result:return result
        time.sleep(.03)
    raise RuntimeError('Timed out waiting for portable operation')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('zip',type=Path);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    work=args.output.resolve()
    if not work.is_relative_to(ROOT/'results') or work.exists():raise ValueError('Use a new output directory under ignored results')
    work.mkdir(parents=True)
    extraction=work/('Extracted package '+chr(0xFC)+chr(0x131)+' with spaces')
    with zipfile.ZipFile(args.zip) as z:
        for name in z.namelist():
            if Path(name).is_absolute() or '..' in Path(name).parts:raise ValueError('Unsafe ZIP name')
        z.extractall(extraction)
    app=extraction/'Monte Carlo Lab CPU'
    if not app.exists():app=extraction  # GitHub artifact ZIP has package files at its root.
    manifest=json.loads((app/'package-manifest.json').read_text())
    for name in manifest['files']:
        assert name.split('/')[0] in ('runtime','resources','licenses','Start Monte Carlo Lab.exe','START_HERE.txt','THIRD_PARTY_NOTICES.txt','dependency-audit.json'),name
        assert not any(x in Path(name).parts for x in ('AGENTS.md','.git','data/local','results','evidence','__pycache__'))
    env={k:v for k,v in os.environ.items() if not k.startswith(('PYTHON','CONDA','VIRTUAL_ENV'))}
    env['PATH']=str(Path(os.environ['SystemRoot'])/'System32')
    env['LOCALAPPDATA']=str(work/('User data '+chr(0xFC)+chr(0x131)+' with spaces'))
    state=work/'launcher-state'
    command=[str(app/'Start Monte Carlo Lab.exe'),'--no-browser','--state-dir',str(state)]
    launcher=subprocess.Popen(command,env=env,cwd=work)
    url=None
    checks=[]
    def api(path,payload=None):
        request=urllib.request.Request(url+path,data=None if payload is None else json.dumps(payload).encode('ascii'),headers={'Origin':url,'Content-Type':'application/json'})
        with urllib.request.urlopen(request,timeout=30) as response:return json.load(response)
    def finish(job):
        ident=job['id']
        job=wait_for(lambda: (j if (j:=api('/api/jobs/'+ident))['state']!='running' else None),60)
        return job
    def run(dataset,engines=None,n=10003):
        return api('/api/run',{'dataset':dataset['id'],'scenarios':n,'seed':'42','horizon_days':10,'engines':engines or [{'backend':'serial'}]})
    def upload(raw=None,metadata=None):
        csvbytes=(app/'resources/local_app/examples/ALPHA.csv').read_bytes() if raw is None else raw
        metabytes=(app/'resources/local_app/examples/ALPHA.json').read_bytes() if metadata is None else metadata
        return {'start':'2024-01-02','end':'2024-01-08','calendar':'nasdaq-2023-2025','assets':[{'csv':base64.b64encode(csvbytes).decode(),'metadata':base64.b64encode(metabytes).decode(),'quantity':1,'format':'existing_csv'}]}
    try:
        wait_for(lambda:(state/'ready.txt').is_file() or launcher.poll() is not None)
        if launcher.poll() is not None:raise RuntimeError('Launcher exited early: '+(state/'startup-error.txt').read_text(encoding='utf-8'))
        url=(state/'ready.txt').read_text()
        service_pid=json.loads((state/'service.json').read_text(encoding='utf-8'))['pid']
        info=api('/api/info')
        assert info['engines']['serial']['available'] and info['engines']['openmp']['available'] and not info['engines']['cuda']['available']
        checks.append('Bundled runtime startup with no installed Python/Git/build tools on PATH; CUDA explicitly unavailable')
        duplicate=subprocess.run(command,env=env,cwd=work,timeout=10)
        assert duplicate.returncode==2
        checks.append('Repeated launcher rejected without opening an unrelated service')
        settings_engines=[{'backend':'serial'},{'backend':'openmp','threads':2}]
        workspace=Path(env['LOCALAPPDATA'])/'MCLabPortable/workspace'
        for kind in ('single','portfolio'):
            dataset=finish(api('/api/data',{'example':kind}));assert dataset['state']=='completed',dataset
            result=finish(run(dataset,settings_engines));assert result['state']=='completed',result
            if kind=='single':
                prices=next(workspace.rglob(dataset['id']))/'0/import/prices.csv'
                prefix=['--csv',str(prices),'10003','42','10','252','--quantity','1']
            else:
                model=next(workspace.rglob(result['id']))/'portfolio.txt'
                prefix=['--portfolio',str(model),'10003','42']
            for actual,config in zip(result['results'],settings_engines):
                options=['--backend',config['backend']]+(['--threads','2'] if config['backend']=='openmp' else [])
                direct=json.loads(subprocess.check_output([str(app/'resources/bin/mc_var.exe')]+prefix+options+['--json'],env=env,cwd=work))
                for key in ('estimates','model','portfolio','calibration','seed','scenarios','backend'):assert direct.get(key)==actual.get(key),key
            with urllib.request.urlopen(url+'/api/jobs/'+result['id']+'/json') as response:assert json.load(response)['results']==result['results']
            with urllib.request.urlopen(url+'/api/jobs/'+result['id']+'/csv') as response:rows=list(csv.DictReader(io.StringIO(response.read().decode('ascii'))))
            assert len(rows)==4
            for row,(r,e) in zip(rows,[(r,e) for r in result['results'] for e in r['estimates']]):
                assert float(row['mc_var'])==e['mc_var'] and float(row['engine_ms'])==r['end_to_end_ms']
            checks.append(kind+': actual serial/OpenMP, direct CLI equality and precise JSON/CSV exports')
        valid=finish(api('/api/data',upload()));assert valid['state']=='completed',valid
        assert finish(run(valid,n=100))['state']=='completed'
        raw=(app/'resources/local_app/examples/ALPHA.csv').read_bytes()
        cases=[upload(b'date,close\n2024-01-02,100\n'),upload(raw.replace(b',101',b',bad',1)),upload(b'\n'.join(x for x in raw.split(b'\n') if not x.startswith(b'2024-01-04'))),upload(metadata=b'{}')]
        for case in cases:
            failed=finish(api('/api/data',case));assert failed['state']=='failed' and failed['error'] and not failed['results'],failed
            assert '.ps1' not in failed['error'] and 'CategoryInfo' not in failed['error']
        assert finish(run(valid,n=100))['state']=='completed'
        checks.append('Supported synthetic upload/calibration, four input rejections, concise errors and recovery')
        running=run(valid,n=10000000)
        cancelled_children=wait_for(lambda:engine_children(service_pid),5)
        api('/api/jobs/'+running['id']+'/cancel',{})
        assert finish(running)['state']=='cancelled'
        assert_exited(cancelled_children)
        assert finish(run(valid,n=100))['state']=='completed'
        checks.append('Actual synthetic cancellation and small-analysis recovery')
        run(valid,n=10000000)
        stopped_children=wait_for(lambda:engine_children(service_pid),5)
        (state/'stop.request').write_text('stop')
        assert launcher.wait(timeout=25)==0
        assert_exited([service_pid]+stopped_children)
        try:urllib.request.urlopen(url+'/api/info',timeout=2);raise AssertionError('Service survived shutdown')
        except (OSError,urllib.error.URLError):pass
        checks.append('Stop request during active operation; launcher exits and loopback service stops')
        for name in ('resources/data/calendars/nasdaq-us-equities-2023-2025.json','resources/local_app/static/index.html'):
            asset=app/name;original=asset.read_bytes()
            try:
                if name.endswith('.json'):asset.unlink()
                else:asset.write_bytes(original+b'changed')
                bad=subprocess.run(command,env=env,cwd=work,timeout=10)
                assert bad.returncode!=0
            finally:asset.write_bytes(original)
        checks.append('Missing calendar and modified UI asset rejected before runtime startup')
        crash_state=work/'crash-state'
        launcher=subprocess.Popen([str(app/'Start Monte Carlo Lab.exe'),'--no-browser','--state-dir',str(crash_state)],env=env,cwd=work)
        wait_for(lambda:(crash_state/'ready.txt').is_file())
        url=(crash_state/'ready.txt').read_text()
        service_pid=json.loads((crash_state/'service.json').read_text(encoding='utf-8'))['pid']
        crash_dataset=finish(api('/api/data',{'example':'single'}))
        run(crash_dataset,n=10000000)
        crash_children=wait_for(lambda:engine_children(service_pid),5)
        launcher.kill();launcher.wait(timeout=10)
        assert_exited([service_pid]+crash_children)
        checks.append('Abrupt launcher termination kills the owned service and active engine via Job Object')
        # Package resources must remain unchanged through normal runs.
        import hashlib
        for name,digest in manifest['files'].items():assert hashlib.sha256((app/name).read_bytes()).hexdigest()==digest,name
        report={'status':'passed','source_revision':manifest['source_revision'],'checks':checks,'extracted_package':str(app),
                'limits':['Developer Windows host with sanitized process environment, not a clean consumer installation','No browser/UI automation in this test','Static native import audit is in dependency-audit.json']}
        (work/'verification.json').write_text(json.dumps(report,indent=2),encoding='ascii')
        print(json.dumps(report,indent=2))
    finally:
        if launcher.poll() is None:
            (state/'stop.request').write_text('stop')
            try:launcher.wait(timeout=25)
            except subprocess.TimeoutExpired:launcher.kill();launcher.wait()


if __name__=='__main__':main()
