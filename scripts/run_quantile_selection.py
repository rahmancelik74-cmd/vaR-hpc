"""Retain a fresh-process CPU quantile microbenchmark, never engine speedup."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess

ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def stamp():return datetime.now(timezone.utc).isoformat()
def save(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=True)+'\n',encoding='ascii')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--exe',type=Path,required=True)
    p.add_argument('--probe',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();exe=args.exe.resolve();probe=args.probe.resolve();out=args.output.resolve()
    if os.name!='nt' or not out.is_relative_to(ROOT/'results') or out.exists():
        raise ValueError('Use Windows and a new output under ignored results')
    subprocess.run(['git','diff','--quiet','HEAD'],cwd=ROOT,check=True)
    env={k:v for k,v in os.environ.items() if not k.startswith(('OMP_','KMP_','GOMP_'))}
    env.update(OMP_DYNAMIC='FALSE',OMP_NESTED='FALSE')
    inventory=json.loads(subprocess.check_output([str(probe),'--inventory'],env=env))
    mask=inventory['process_mask_hex']
    out.mkdir(parents=True);save(out/'inventory.json',inventory)
    manifest={'schema_version':1,'status':'running','started_utc':stamp(),
      'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
      'executable_sha256':digest(exe),'probe_sha256':digest(probe),
      'input':'data/synthetic_prices.csv','input_sha256':digest(ROOT/'data/synthetic_prices.csv'),
      'scope':'Quantile-stage-only; not total engine time or a CPU/GPU comparison',
      'timer_includes':'Full sort + rank lookup + result vector allocation OR rank planning + suffix nth_element + result vector allocation',
      'timer_excludes':'CSV calibration, allocation of loss vector, RNG/loss generation, fingerprint, process startup, output, loss-buffer cleanup',
      'input_policy':'Fresh identical serial-native losses per process, seed 42, model calibrated from fixed synthetic CSV; finite samples',
      'warmups':3,'measured_repeats':10,'scenario_counts':[100000,1000000,10000000],
      'process_policy':'Full inherited processor pool, normal priority; no per-core pinning; no power changes',
      'conditions':'Interactive host; competing applications uncontrolled; temperature, cooling and thermal equilibrium unknown',
      'outlier_policy':'Retain all samples; abort and retain failed attempt if process or power checks fail'}
    save(out/'manifest.json',manifest)
    records=[]
    def launch(arguments):
        run=subprocess.run([str(probe),'--run',mask,str(exe)]+arguments,cwd=ROOT,env=env,capture_output=True)
        if run.returncode:
            save(out/'launcher-failure.json',{'returncode':run.returncode,
              'stdout':run.stdout.decode('utf-8',errors='replace'),
              'stderr':run.stderr.decode('utf-8',errors='replace')})
            raise RuntimeError('Probe failed; launcher output retained')
        return json.loads(run.stdout)
    def check_observation(observation):
        assert observation['exit_code']==0 and not observation['stderr'] and not observation['timed_out']
        assert observation['process_mask_hex']==mask and observation['priority_class']==32
        assert observation['owned_tree_exited']
        for side in ('before','after'):
            power=observation[side]
            assert power['ac_line_status']==1,'AC power required'
            assert power['active_power_scheme']==inventory['power']['active_power_scheme']
            assert power['battery_saver']==inventory['power']['battery_saver']
    try:
        validation=launch(['--validate',manifest['input'],'10000000'])
        save(out/'validation.json',validation)
        check_observation(validation)
        check=json.loads(validation['stdout'])
        assert check['validation']=='passed' and check['native_scenarios']==10000000
        assert check['analytical_acceptance_checked'] and check['exact_equality'] and check['common_inputs_unchanged']
        for phase,rounds in [('warmup',3),('measured',10)]:
            for repeat in range(1,rounds+1):
                sizes=manifest['scenario_counts'][::(1 if repeat%2 else -1)]
                for n in sizes:
                    methods=['sort','nth'] if repeat%2 else ['nth','sort']
                    for method in methods:
                        # Save every raw observation before checking numerical/timing content.
                        observation=launch(['--csv',manifest['input'],str(n),'42',method])
                        record={'sequence':len(records)+1,'timestamp_utc':stamp(),'phase':phase,'repeat':repeat,
                          'scenarios':n,'method':method,'observation':observation}
                        with (out/'runs.jsonl').open('a',encoding='ascii') as stream:
                            stream.write(json.dumps(record,ensure_ascii=True)+'\n')
                        records.append(record)
                        check_observation(observation)
                        result=json.loads(observation['stdout'])
                        assert result['scenarios']==n and result['method']==method and result['seed']=='42'
                        assert result['scope']=='quantile-stage-only'
                        assert math.isfinite(result['quantile_ms']) and result['quantile_ms']>=0
                print(f'{phase} {repeat}/{rounds}',flush=True)
        rows=[]
        for n in manifest['scenario_counts']:
            all_n=[json.loads(r['observation']['stdout']) for r in records if r['scenarios']==n]
            assert all(r['estimates']==all_n[0]['estimates'] and r['input_loss_fnv1a64']==all_n[0]['input_loss_fnv1a64'] for r in all_n)
            row={'scenarios':n,'input_loss_fnv1a64':all_n[0]['input_loss_fnv1a64'],'estimates':all_n[0]['estimates']}
            for method in ('sort','nth'):
                values=[json.loads(r['observation']['stdout'])['quantile_ms'] for r in records
                  if r['phase']=='measured' and r['scenarios']==n and r['method']==method]
                assert len(values)==10
                row[method+'_mean_ms']=statistics.mean(values)
                row[method+'_sample_sd_ms']=statistics.stdev(values)
            row['stage_speedup_ratio_of_means']=row['sort_mean_ms']/row['nth_mean_ms']
            rows.append(row)
        assert len(records)==78
        assert digest(exe)==manifest['executable_sha256'] and digest(probe)==manifest['probe_sha256']
        save(out/'summary.json',rows)
        manifest.update(status='completed',total_timed_processes=78,warmup_processes=18,measured_processes=60,
          validation_processes=1)
    except Exception as error:
        manifest.update(status='failed',failure=str(error));raise
    finally:
        manifest['finished_utc']=stamp();save(out/'manifest.json',manifest)
        save(out/'artifact-sha256.json',{p.name:digest(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='artifact-sha256.json'})

if __name__=='__main__':main()
