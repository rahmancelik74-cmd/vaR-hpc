"""Audit retained quantile experiment arithmetic and integrity, without simulations."""
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

def verify(folder):
    manifest=json.loads((folder/'manifest.json').read_text())
    assert manifest['status']=='completed'
    hashes=json.loads((folder/'artifact-sha256.json').read_text())
    for name,digest in hashes.items():assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==digest,name
    records=[json.loads(line) for line in (folder/'runs.jsonl').read_text().splitlines()]
    assert len(records)==78 and [r['sequence'] for r in records]==list(range(1,79))
    assert sum(r['phase']=='warmup' for r in records)==18
    inventory=json.loads((folder/'inventory.json').read_text())
    for record in records:
        obs=record['observation'];result=json.loads(obs['stdout'])
        assert obs['exit_code']==0 and not obs['stderr'] and not obs['timed_out'] and obs['owned_tree_exited']
        assert obs['process_mask_hex']==inventory['process_mask_hex'] and obs['priority_class']==32
        for side in ['before','after']:
            assert obs[side]['ac_line_status']==1
            assert obs[side]['active_power_scheme']==inventory['power']['active_power_scheme']
            assert obs[side]['battery_saver']==inventory['power']['battery_saver']
        assert result['scenarios']==record['scenarios'] and result['method']==record['method']
        assert result['scope']=='quantile-stage-only' and result['seed']=='42'
        assert math.isfinite(result['quantile_ms']) and result['quantile_ms']>=0
    summary=json.loads((folder/'summary.json').read_text())
    assert [r['scenarios'] for r in summary]==[100000,1000000,10000000]
    for row in summary:
        for method in ['sort','nth']:
            group=[r for r in records if r['scenarios']==row['scenarios'] and r['method']==method]
            for phase,count in [('warmup',3),('measured',10)]:
                assert sorted(r['repeat'] for r in group if r['phase']==phase)==list(range(1,count+1))
            results=[json.loads(r['observation']['stdout']) for r in group]
            assert all(r['input_loss_fnv1a64']==row['input_loss_fnv1a64'] and r['estimates']==row['estimates'] for r in results)
            values=[json.loads(r['observation']['stdout'])['quantile_ms'] for r in group if r['phase']=='measured']
            assert math.isclose(statistics.mean(values),row[method+'_mean_ms'],rel_tol=1e-12)
            assert math.isclose(statistics.stdev(values),row[method+'_sample_sd_ms'],rel_tol=1e-12)
        assert math.isclose(row['stage_speedup_ratio_of_means'],row['sort_mean_ms']/row['nth_mean_ms'],rel_tol=1e-12)
    validation=json.loads((folder/'validation.json').read_text())
    assert validation['exit_code']==0 and not validation['stderr'] and not validation['timed_out']
    v=json.loads(validation['stdout'])
    assert v['native_scenarios']==10000000 and v['native_seeds']==[42,123,456,789,2026]
    assert v['exact_equality'] and v['common_inputs_unchanged'] and v['analytical_acceptance_checked']
    assert v['common_openmp_threads']==[1,2,4,8,10]
    assert len(v['native_values'])==5 and all(len(pair)==2 for pair in v['native_values'])
    for index,confidence in [(0,'95'),(1,'99')]:
        mean=statistics.mean(pair[index] for pair in v['native_values'])
        assert math.isclose(mean,v['mean_var'+confidence],rel_tol=1e-12)
        analytical=v['analytical_var'+confidence]
        assert abs(mean-analytical)<=.01*max(abs(analytical),.01*v['initial_value'])
    print('PASS: 78 timed processes, complete 3+10 coverage, matched loss fingerprints/quantiles, sample statistics, five-seed acceptance and exact-byte hashes.')

if __name__=='__main__':verify(Path(sys.argv[1]))
