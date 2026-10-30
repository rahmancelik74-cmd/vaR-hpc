"""Build an allowlisted CPU portable ZIP. Standard library only; Windows build tools required."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from start_local import build, source_hash
PYTHON_URL='https://www.python.org/ftp/python/3.14.9/python-3.14.9-embed-amd64.zip'
PYTHON_SHA='3c01d7cfc666f746a6f064f60fb2156ab0ec464d3d738ab796371a46a9bb24a2'
RUNTIME=['python.exe','python314.dll','python3.dll','vcruntime140.dll','vcruntime140_1.dll',
         'select.pyd','_socket.pyd','unicodedata.pyd','python314.zip','python314._pth','LICENSE.txt']
ASSETS=['local_app/server.py','local_app/static/index.html','local_app/static/app.js','local_app/static/style.css',
        'scripts/calibrate_portfolio.py','scripts/equity-data-common.ps1','scripts/import-equity-data.ps1',
        'data/calendars/nasdaq-us-equities-2023-2025.json']
ASSETS += ['local_app/examples/'+x for x in ['ALPHA.csv','ALPHA.json','BETA.csv','BETA.json','request-single.json','request-portfolio.json']]
CRT=['msvcp140.dll','msvcp140_1.dll','msvcp140_2.dll','msvcp140_atomic_wait.dll','msvcp140_codecvt_ids.dll',
     'vcruntime140.dll','vcruntime140_1.dll','vcruntime140_threads.dll','concrt140.dll']


def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,indent=2,ensure_ascii=True)+'\n',encoding='ascii')
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)


def environment():
    vswhere=Path(os.environ['ProgramFiles(x86)'])/'Microsoft Visual Studio/Installer/vswhere.exe'
    install=Path(subprocess.check_output([str(vswhere),'-latest','-property','installationPath'],text=True).strip())
    setup=install/'Common7/Tools/VsDevCmd.bat'
    output=subprocess.check_output(f'cmd.exe /d /s /c ""{setup}" -arch=x64 -host_arch=x64 >nul && set"',text=True)
    env={k.upper():v for k,v in os.environ.items()}
    for line in output.splitlines():
        key,sep,value=line.partition('=')
        if key and sep:env[key.upper()]=value
    return install,env


def dependencies(stage,env):
    report={}
    system=Path(os.environ['SystemRoot'])/'System32'
    for p in stage.rglob('*'):
        if p.suffix.lower() not in ('.exe','.dll','.pyd'):continue
        out=subprocess.check_output(['dumpbin.exe','/dependents',str(p)],env=env,text=True)
        names=sorted(set(re.findall(r'^\s+([A-Za-z0-9_.-]+\.dll)\s*$',out,re.M|re.I)),key=str.lower)
        for name in names:
            bundled=(p.parent/name).is_file()
            os_contract=name.lower().startswith(('api-ms-win-','ext-ms-win-'))
            sensitive=name.lower().startswith(('python','vcruntime','msvcp','vcomp','lib'))
            if not bundled and (sensitive or not (os_contract or (system/name).is_file())):
                raise RuntimeError('Unresolved package dependency: '+p.name+' -> '+name)
        report[p.relative_to(stage).as_posix()]=names
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    out=args.output.resolve()
    if not out.is_relative_to(ROOT/'results') or out.exists():raise ValueError('Output must be a new directory below ignored results')
    if os.name!='nt':raise RuntimeError('Windows x64 builder required')
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','diff','HEAD','--name-only'],cwd=ROOT))
    for variable in ('CL','_CL_','CFLAGS','CXXFLAGS'):
        os.environ.pop(variable,None)  # Build-process-only isolation, never global settings.
    executable=build(False,True)
    install,env=environment()
    stage=out/'Monte Carlo Lab CPU';stage.mkdir(parents=True)
    for name in ASSETS:copy(ROOT/name,stage/'resources'/name)
    copy(ROOT/'packaging/portable_entry.py',stage/'resources/portable_entry.py')
    copy(executable,stage/'resources/bin/mc_var.exe')
    # Trusted shared importer implementation reused verbatim as a fixed command.
    common=(ROOT/'scripts/equity-data-common.ps1').read_text(encoding='ascii')
    wrapper='''
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$ErrorActionPreference='Stop'
$PSScriptRoot=''
$request=[IO.File]::ReadAllText($requestPath,[Text.Encoding]::UTF8) | ConvertFrom-Json
$params=@{};$request.PSObject.Properties | ForEach-Object { $params[$_.Name]=$_.Value }
try { Convert-EquityData @params | ConvertTo-Json -Depth 12 }
catch { Write-EquityJson $request.ErrorReportFile @{schema_version=1;code=$_.Exception.Data['validation_code']};throw }
'''
    (stage/'resources/scripts/portable-import.txt').write_text(common+wrapper,encoding='ascii')
    cache=ROOT/'build-portable-tools';cache.mkdir(exist_ok=True)
    archive=cache/'python-3.14.9-embed-amd64.zip'
    if not archive.exists():archive.write_bytes(urllib.request.urlopen(PYTHON_URL,timeout=60).read())
    if digest(archive)!=PYTHON_SHA:raise ValueError('Official embedded runtime checksum mismatch')
    with zipfile.ZipFile(archive) as z:
        for name in RUNTIME:
            dest=stage/'runtime'/name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(z.read(name))
    (stage/'runtime/python314._pth').write_text('python314.zip\n.\n../resources\n',encoding='ascii')
    # Only redistributable, non-debug desktop x64 folders. No System32 copying.
    redist=Path(env['VCTOOLSREDISTDIR'])/'x64'
    for name in CRT:
        if (redist/'Microsoft.VC143.CRT'/name).exists():copy(redist/'Microsoft.VC143.CRT'/name,stage/'resources/bin'/name)
    copy(redist/'Microsoft.VC143.OpenMP/vcomp140.dll',stage/'resources/bin/vcomp140.dll')
    subprocess.run(['mt.exe','-nologo','-manifest',str(ROOT/'packaging/windows-utf8.manifest'),
                    '-outputresource:'+str(stage/'resources/bin/mc_var.exe')+';#1'],env=env,check=True)
    launcher=stage/'Start Monte Carlo Lab.exe'
    compiler=install/'VC/Tools/MSVC'/env['VCTOOLSVERSION'].strip('/\\')/'bin/Hostx64/x64/cl.exe'
    env['PATH']=str(compiler.parent)+';'+env['PATH']
    subprocess.run([str(compiler),'/nologo','/std:c++17','/EHsc','/O2','/MT',str(ROOT/'packaging/launcher.cpp'),
                    '/Fo'+str(out/'launcher.obj'),'/Fe'+str(launcher),'/link','/SUBSYSTEM:WINDOWS'],cwd=out,env=env,check=True)
    copy(ROOT/'packaging/START_HERE.txt',stage/'START_HERE.txt')
    copy(ROOT/'packaging/THIRD_PARTY_NOTICES.txt',stage/'THIRD_PARTY_NOTICES.txt')
    # Include upstream license text unmodified, in addition to its runtime copy.
    copy(stage/'runtime/LICENSE.txt',stage/'licenses/Python-LICENSE.txt')
    license_edition=install.name if install.name in ('Community','Professional','Enterprise') else 'Community'
    license_url=f'https://visualstudio.microsoft.com/wp-content/uploads/2021/11/Visual-Studio-2022-{license_edition}-License-EN.docx'
    (stage/'licenses/Visual-Studio-2022-License.docx').write_bytes(urllib.request.urlopen(license_url,timeout=60).read())
    audit=dependencies(stage,env)
    save(stage/'dependency-audit.json',audit)
    files={p.relative_to(stage).as_posix():digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}
    manifest=dict(schema_version=1,package_version='1',edition='cpu',configuration='Release',source_revision=revision,
                  source_tracked_worktree_dirty_at_build=dirty,source_sha256=source_hash(),runtime='CPython 3.14.9 embedded x64 (trimmed optional extensions)',
                  runtime_upstream_url=PYTHON_URL,runtime_upstream_sha256=PYTHON_SHA,
                  compiler_toolset=env['VCTOOLSVERSION'].strip('/\\'),vs_builder_edition=license_edition,
                  engine_windows_codepage='UTF-8 application manifest',cpu_target='baseline MSVC x64; no /arch override',files=files)
    save(stage/'package-manifest.json',manifest)
    hashes={**files,'package-manifest.json':digest(stage/'package-manifest.json')}
    (stage/'integrity.sha256').write_text(''.join(f'{value}  {name}\n' for name,value in sorted(hashes.items())),encoding='ascii')
    target=out/f'mc-lab-portable-cpu-v1-{revision[:12]}.zip'
    with zipfile.ZipFile(target,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(stage.rglob('*')):
            if p.is_file():z.write(p,p.relative_to(out))
    (out/(target.name+'.sha256')).write_text(digest(target)+'  '+target.name+'\n',encoding='ascii')
    save(out/'artifact.json',{'zip':target.name,'sha256':digest(target),'size_bytes':target.stat().st_size,'source_revision':revision,'dirty':dirty})
    print(json.dumps({'zip':str(target),'sha256':digest(target),'size_bytes':target.stat().st_size}))


if __name__=='__main__':main()
