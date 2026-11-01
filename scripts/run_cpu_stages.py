"""Record a separate Windows CPU stage diagnostic; never replace primary timings."""
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import time
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]
FIELDS=('setup_ms','generation_ms','sorting_ms','quantile_ms','cleanup_ms','end_to_end_ms')

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def stamp():return datetime.now(timezone.utc).isoformat()
def save(path,obj):path.write_text(json.dumps(obj,indent=2,ensure_ascii=True)+'\n',encoding='ascii')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe',type=Path,required=True)
    parser.add_argument('--probe',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();exe=args.exe.resolve();probe=args.probe.resolve();out=args.output.resolve()
    if os.name!='nt' or not out.is_relative_to(ROOT/'results') or out.exists():
        raise ValueError('Use Windows and a new output directory under ignored results')
    subprocess.run(['git','diff','--quiet','HEAD'],cwd=ROOT,check=True)
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    env=os.environ.copy()
    for name in list(env):
        if name.startswith(('OMP_','KMP_','GOMP_')):del env[name]
    env.update(OMP_DYNAMIC='FALSE',OMP_NESTED='FALSE')
    inventory=json.loads(subprocess.check_output([str(probe),'--inventory'],env=env))
    out.mkdir(parents=True)
    save(out/'inventory.json',inventory)
    mask=inventory['process_mask_hex']
    plan={'schema_version':1,'status':'running','started_utc':stamp(),'source_revision':revision,
          'tracked_worktree_clean':True,'git_status':subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True),
          'executable_sha256':digest(exe),'probe_sha256':digest(probe),'input_sha256':digest(ROOT/'data/synthetic_prices.csv'),
          'input':'data/synthetic_prices.csv','seed':'42','horizon_days':10,'annual_days':252,
          'scenario_counts':[100000,1000000,10000000],'openmp_threads':[1,2,4,8,10],
          'warmups':3,'measured_repeats':10,'scope':'Separate opt-in CPU host stage diagnostic; not historical primary benchmark',
          'process_policy':'Fresh process, verified full inherited affinity pool and normal priority via mc_cpu_probe; no per-core pinning',
          'conditions':{'charger':'Queried per sample','ambient_temperature':'Not measured','cooling':'Not recorded',
                        'competing_applications':'Interactive developer host; not controlled; VM/browser may be active',
                        'thermal_equilibrium':'Not established','power_plan':'Observed only; never changed'},
          'outlier_policy':'Retain every sample; failure/power change stops campaign without selective replacement'}
    save(out/'manifest.json',plan)
    configurations=[(n,backend,t) for n in plan['scenario_counts'] for backend,t in [('serial',0)]+[('openmp',v) for v in plan['openmp_threads']]]
    records=[]
    try:
        for phase,rounds in [('warmup',3),('measured',10)]:
            for repeat in range(rounds):
                order=list(range(len(configurations)))
                if repeat%2==0:order.reverse()
                offset=(5*repeat)%len(order);order=order[offset:]+order[:offset]
                for index in order:
                    n,backend,threads=configurations[index]
                    command=[str(probe),'--run',mask,str(exe),'--csv',str(ROOT/'data/synthetic_prices.csv'),str(n),'42','10','252','--backend',backend]
                    if threads:command+=['--threads',str(threads)]
                    command+=['--cpu-diagnostics','--json']
                    raw=subprocess.check_output(command,cwd=ROOT,env=env)
                    observation=json.loads(raw)
                    record={'sequence':len(records)+1,'timestamp_utc':stamp(),'phase':phase,'repeat':repeat+1,
                            'scenarios':n,'backend':backend,'threads':threads,'observation':observation}
                    with (out/'runs.jsonl').open('a',encoding='ascii') as stream:stream.write(json.dumps(record,ensure_ascii=True)+'\n')
                    records.append(record)
                    assert observation['exit_code']==0 and not observation['stderr'] and not observation['timed_out']
                    assert observation['process_mask_hex']==mask and observation['priority_class']==32
                    for side in ('before','after'):
                        power=observation[side]
                        assert power['ac_line_status']==1, 'AC power required; retain failed attempt'
                        assert power['active_power_scheme']==inventory['power']['active_power_scheme']
                        assert power['battery_saver']==inventory['power']['battery_saver']
                    result=json.loads(observation['stdout']);d=result['cpu_diagnostics']
                    assert result['threads_used']==(threads or 1)
                    values=[d[name] for name in FIELDS[:-1]]
                    assert all(math.isfinite(v) and v>=0 for v in values)
                    assert math.isclose(sum(values),result['end_to_end_ms'],rel_tol=1e-10,abs_tol=1e-8)
                    time.sleep(.1)
                print(f'{phase} round {repeat+1}/{rounds}',flush=True)
        rows=[]
        for n,backend,threads in configurations:
            group=[json.loads(r['observation']['stdout']) for r in records if r['phase']=='measured' and
                   (r['scenarios'],r['backend'],r['threads'])==(n,backend,threads)]
            assert len(group)==10
            assert all(g['estimates']==group[0]['estimates'] for g in group)
            row={'scenarios':n,'backend':backend,'threads':threads,'count':len(group)}
            for field in FIELDS:
                values=[g[field] if field=='end_to_end_ms' else g['cpu_diagnostics'][field] for g in group]
                row[field+'_mean']=statistics.mean(values);row[field+'_sample_sd']=statistics.stdev(values)
            row['sorting_fraction']=row['sorting_ms_mean']/row['end_to_end_ms_mean']
            rows.append(row)
        save(out/'summary.json',rows)
        with (out/'summary.csv').open('w',newline='',encoding='ascii') as stream:
            writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
        assert len(records)==234
        assert digest(exe)==plan['executable_sha256'] and digest(probe)==plan['probe_sha256']
        plan.update(status='completed',total_runs=len(records),measured_runs=180,warmup_runs=54)
    except Exception as error:
        plan.update(status='failed',failure=str(error));raise
    finally:
        plan['finished_utc']=stamp();save(out/'manifest.json',plan)
        save(out/'artifact-sha256.json',{p.name:digest(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='artifact-sha256.json'})

if __name__=='__main__':main()
