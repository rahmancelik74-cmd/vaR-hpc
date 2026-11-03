"""Sequential fresh-process matched full-engine study; retain all observations."""
import csv, hashlib, json, os, statistics, subprocess, time
from pathlib import Path
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results/performance-study-20261103-run1'
EXE=ROOT/'build-local-app-cuda/mc_var.exe'
PROBE=ROOT/'build-cpu-stages/mc_cpu_probe.exe'
def save(p,x): p.write_text(json.dumps(x,indent=2)+'\n',encoding='ascii')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def table(p,rows):
    with p.open('w',newline='',encoding='ascii') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main():
    OUT.mkdir(exist_ok=False)
    env={k:v for k,v in os.environ.items() if not k.startswith(('OMP_','KMP_','GOMP_'))}
    env.update(OMP_DYNAMIC='FALSE',OMP_NESTED='FALSE')
    inv=json.loads(subprocess.check_output([str(PROBE),'--inventory'],env=env));save(OUT/'inventory.json',inv)
    configs=[('serial',0,0,'')]+[('openmp',t,0,'') for t in [1,2,4,8,10]]+ [('openmp',t,t,'') for t in [1,2,4,8,10]]+[('cuda',0,0,'full-device'),('cuda',0,0,'hybrid')]
    plan={'source_sha':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'exe_sha256':sha(EXE),'probe_sha256':sha(PROBE),'fixture_sha256':sha(ROOT/'data/synthetic_prices.csv'),'configs':configs,'counts':[100000,1000000,10000000],'warmups':3,'measurements':10,'seed':42,'horizon':'10/252','order':'GPU diagnostic 3+10, validation, then N ascending / configurations listed / warmups then measured ascending; sequential fresh processes and CUDA contexts','timing':'Engine host wall allocation RNG loss full sort rank transfers synchronization cleanup; excludes CSV/calibration process startup output. Diagnostic Event overhead separate.','conditions':'Observed power only; no setting changes; other apps uncontrolled; CPU temperatures, clocks, ambient and thermal equilibrium unknown','started_utc':datetime.now(timezone.utc).isoformat(),'status':'running'}
    save(OUT/'manifest.json',plan)
    records=[]
    def run(kind,n,c,phase,rep,seed=42,diag=False):
        b,t,s,m=c
        args=['--csv',str(ROOT/'data/synthetic_prices.csv'),str(n),str(seed),'10','252','--backend',b]
        if t:args+=['--threads',str(t)]
        if s:args+=['--sort-threads',str(s)]
        if m:args+=['--cuda-mode',m]
        if m=='hybrid':args+=['--batch-size','65535']
        if diag:args+=['--cuda-diagnostics']
        args+=['--json']
        command=[str(PROBE),'--run',inv['process_mask_hex'],str(EXE)]+args
        proc=subprocess.run(command,capture_output=True,env=env)
        record={'sequence':len(records)+1,'kind':kind,'n':n,'config':c,'phase':phase,'repeat':rep,'seed':seed,'command':command,'launcher_exit':proc.returncode,'raw_stdout':proc.stdout.decode(errors='replace'),'raw_stderr':proc.stderr.decode(errors='replace')}
        with (OUT/'runs.jsonl').open('a',encoding='ascii') as f:f.write(json.dumps(record)+'\n')
        records.append(record)
        assert proc.returncode==0
        obs=json.loads(proc.stdout);assert obs['exit_code']==0 and not obs['timed_out'] and not obs['stderr'] and obs['owned_tree_exited']
        assert obs['process_mask_hex']==inv['process_mask_hex'] and obs['priority_class']==32
        for side in ['before','after']:
            assert obs[side]['ac_line_status']==1
            assert obs[side]['active_power_scheme']==inv['power']['active_power_scheme']
            assert obs[side]['battery_saver']==inv['power']['battery_saver']
        return json.loads(obs['stdout'])
    for phase,count in [('warmup',3),('measured',10)]:
        for rep in range(1,count+1):run('gpu-diagnostic',10000000,configs[-2],phase,rep,diag=True)
    print('GPU diagnostics complete',flush=True)
    validation=[]
    for c in configs[6:11]:
        results=[run('analytical',10000000,c,'validation',i+1,seed) for i,seed in enumerate([42,43,44,45,46])]
        for j in range(2):
            ref=results[0]['estimates'][j]['analytical_var'];mean=statistics.mean(r['estimates'][j]['mc_var'] for r in results)
            limit=.01*max(abs(ref),.01*results[0]['model']['initial_value'])
            validation.append({'config':c,'confidence':results[0]['estimates'][j]['confidence'],'mean':mean,'reference':ref,'limit':limit,'passed':abs(mean-ref)<=limit})
    save(OUT/'analytical.json',validation);assert all(r['passed'] for r in validation)
    print('Five-seed analytical acceptance passed',flush=True)
    for n in plan['counts']:
        for c in configs:
            for phase,count in [('warmup',3),('measured',10)]:
                for rep in range(1,count+1):run('primary',n,c,phase,rep)
            print(n,c,'complete',flush=True)
    rows=[]
    def result(r):return json.loads(json.loads(r['raw_stdout'])['stdout'])
    for n in plan['counts']:
        group=[]
        for c in configs:
            rs=[result(r) for r in records if r['kind']=='primary' and r['n']==n and r['config']==c and r['phase']=='measured'];assert len(rs)==10
            xs=[r['end_to_end_ms'] for r in rs];mean=statistics.mean(xs)
            group.append(dict(n=n,backend=c[0],generation_threads=c[1] or 1,sort_team_bound=c[2] or 1,mode=c[3],mean_ms=mean,sample_sd_ms=statistics.stdev(xs),scenarios_per_second=n*1000/mean))
        serial=group[0]['mean_ms'];omp=min(r['mean_ms'] for r in group[1:6]);parallel=min(r['mean_ms'] for r in group[6:11])
        for r in group:r.update(ratio_serial=serial/r['mean_ms'],ratio_best_original_openmp=omp/r['mean_ms'],ratio_best_parallel_cpu=parallel/r['mean_ms'])
        rows+=group
    table(OUT/'aggregate.csv',rows);save(OUT/'aggregate.json',rows)
    ds=[result(r) for r in records if r['kind']=='gpu-diagnostic' and r['phase']=='measured'];stages=[]
    for field in ['initialization_ms','rng_ms','loss_ms','cub_ms','gather_ms','pipeline_span_ms','covered_device_stage_sum_ms','host_quantile_ms','host_to_device_ms','device_to_host_ms','end_to_end_ms']:
        xs=[d[field] if field=='end_to_end_ms' else d['cuda'].get(field,d['cuda']['diagnostics'].get(field)) for d in ds]
        mean=statistics.mean(xs);stages.append(dict(stage=field,mean_ms=mean,sample_sd_ms=statistics.stdev(xs),percent_host=100*mean/statistics.mean(d['end_to_end_ms'] for d in ds),percent_covered=100*mean/statistics.mean(d['cuda']['diagnostics']['covered_device_stage_sum_ms'] for d in ds)))
    table(OUT/'gpu-stages.csv',stages);save(OUT/'gpu-stages.json',stages)
    assert sha(EXE)==plan['exe_sha256'];assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==plan['source_sha']
    plan['status']='completed';save(OUT/'manifest.json',plan)
    save(OUT/'artifact-sha256.json',{p.name:sha(p) for p in OUT.iterdir() if p.is_file() and p.name!='artifact-sha256.json'})
if __name__=='__main__':main()
