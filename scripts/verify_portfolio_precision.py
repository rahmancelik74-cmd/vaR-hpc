"""Read-only public arithmetic and integrity; --local checks retained 80M files.

Standard-library default for hosted CI. Never generate samples or run engines.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PUBLIC=ROOT/'evidence/portfolio-precision-20261025-v1'
OLD=ROOT/'evidence/portfolio-campaign-20261025'


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):
            h.update(b)
    return h.hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='ascii'))


def rows(path):
    with Path(path).open(newline='',encoding='ascii') as f:
        return list(csv.DictReader(f))


def close(a,b):
    assert math.isclose(float(a),float(b),abs_tol=1e-11,rel_tol=1e-12),(a,b)


def verify(local=False):
    for name,value in load(PUBLIC/'freeze-v1.json').items():
        assert sha(ROOT/name)==value,name
    inventory=load(PUBLIC/'artifact-sha256.json')
    expected={p.relative_to(ROOT).as_posix() for p in PUBLIC.rglob('*') if p.is_file() and p.name not in ('artifact-sha256.json','delivery-files.json')}
    expected.update('scripts/'+name for name in ('portfolio_precision.py','verify_portfolio_precision.py',
        'plot_portfolio_precision.py','audit_portfolio_precision.py','deliver-portfolio-precision.ps1'))
    assert set(inventory)==expected,'Artifact inventory scope mismatch'
    for name,value in inventory.items():
        assert sha(ROOT/name)==value,name
    p=load(PUBLIC/'protocol-v1.json'); ref=load(PUBLIC/'reference.json'); num=load(PUBLIC/'numerical.json')
    assert ref['status']==num['status']=='complete'
    assert p['samples_per_fixture']==p['hard_sample_ceiling_per_fixture']==80000000
    assert p['interval_count']==4 and p['per_interval_error']*4==p['family_error']==.01
    assert ref['protocol_sha256']==sha(PUBLIC/'protocol-v1.json')
    assert ref['freeze_sha256']==sha(PUBLIC/'freeze-v1.json')
    assert ref['source_exact_sha256']==sha(ROOT/'scripts/portfolio_precision.py')
    oldp=load(OLD/'protocol-v1.json')
    assert not set(p['seeds'].values()) & (set(oldp['reference']['seeds'].values())|set(oldp['validation_seeds']))
    table=rows(PUBLIC/'reassessment.csv'); old=rows(OLD/'convergence.csv'); raw=rows(OLD/'validation-raw.csv')
    assert len(table)==12 and len({(r['fixture'],r['config'],r['confidence']) for r in table})==12
    assert sum(r['old_status']=='inconclusive' for r in table)==9
    for r in table:
        key=lambda x: x['fixture']==r['fixture'] and x['config']==r['config'] and int(x['scenarios'])==10000000
        prior=next(x for x in old if key(x) and float(x['confidence'])==float(r['confidence']))
        assert r['mean_var']==prior['mean_var']
        for a,b in [('old_status','practical'),('old_reference','reference'),('old_lower','reference_lower'),('old_upper','reference_upper')]:
            assert r[a]==prior[b]
        selected=[x for x in raw if key(x)]
        assert sorted(int(x['seed']) for x in selected)==oldp['validation_seeds']
        close(r['mean_var'],math.fsum(float(x['var'+str(round(float(r['confidence'])*100))]) for x in selected)/5)
        case=ref['cases'][r['fixture']]
        assert case['scenarios']==80000000 and case['seed']==p['seeds'][r['fixture']]
        assert case['fixture']==p['fixtures'][r['fixture']]
        q=next(x for x in case['quantiles'] if x['confidence']==float(r['confidence']))
        for a,b in [('reference','var'),('lower','lower'),('upper','upper'),('new_width','width')]:
            close(r[a],q[b])
        close(q['width'],q['upper']-q['lower'])
        assert q['coverage']>=1-p['per_interval_error']-1e-12
        target=.0005*case['initial_value']; close(r['practical_target'],target)
        m=float(r['mean_var']); lo=q['lower']; hi=q['upper']
        worst=max(abs(m-lo),abs(m-hi)); best=max(lo-m,m-hi,0)
        close(r['worst_error'],worst)
        expected='pass' if worst<=target else 'fail' if best>target else 'inconclusive'
        if hi-lo>target:
            expected='inconclusive'
        assert r['new_status']==expected
        n=next(x for x in num['cases'][r['fixture']] if x['confidence']==float(r['confidence']))
        close(r['numerical_var'],n['modes']['primary']['var'])
        spread=max(x['var'] for x in n['modes'].values())-min(x['var'] for x in n['modes'].values())
        close(r['numerical_mode_spread'],spread)
        assert spread<1e-7
        assert lo<=float(r['numerical_var'])<=hi
        for mode in n['modes'].values():
            assert mode['cdf_residual']<1e-10 and mode['quadrature_error_estimate']<1e-9
        for observed,exact,se in [('sample_terminal_mean','exact_terminal_mean','mean_standard_error'),('sample_terminal_second_moment','exact_terminal_second_moment','second_moment_standard_error')]:
            assert abs(case[observed]-case[exact])<8*case[se]
    complete=load(PUBLIC/'completion.json')
    assert complete['endpoint_totals']=={s:sum(r['new_status']==s for r in table) for s in ('pass','fail','inconclusive')}
    assert complete['previously_inconclusive_totals']=={s:sum(r['new_status']==s and r['old_status']=='inconclusive' for r in table) for s in ('pass','fail','inconclusive')}
    five=[r for r in old if r['fixture']=='five-identity' and int(r['scenarios'])==10000000]
    assert len(five)==6 and all(r['practical']=='pass' for r in five)
    if (PUBLIC/'figure-data.json').exists():
        figure=load(PUBLIC/'figure-data.json')
        assert figure['csv_sha256']==sha(PUBLIC/'reassessment.csv')
        assert len(figure['data'])==4
        for point in figure['data']:
            selected=[r for r in table if r['fixture']==point['fixture'] and float(r['confidence'])==point['confidence']]
            r=selected[0]; center=float(r['numerical_var'])
            close(point['center'],center); close(point['target'],r['practical_target'])
            for key,cols in [('old_relative_interval',('old_lower','old_upper')),('new_relative_interval',('lower','upper'))]:
                for actual,col in zip(point[key],cols):
                    close(actual,float(r[col])-center)
            assert [v[0] for v in point['relative_means']]==[x['config'] for x in selected]
            for (_,actual),r in zip(point['relative_means'],selected):
                close(actual,float(r['mean_var'])-center)
    if local:
        import numpy as np
        from scipy.stats import binom
        for name,case in ref['cases'].items():
            path=ROOT/case['array_path']
            assert sha(path)==case['array_sha256'] and path.stat().st_size==case['array_bytes']
            a=np.load(path,mmap_mode='r'); assert a.dtype==np.float64 and len(a)==80000000
            for start in range(0,len(a),250000):
                chunk=a[max(0,start-1):start+250000]
                assert np.isfinite(chunk).all() and np.all(chunk[1:]>=chunk[:-1])
            for q in case['quantiles']:
                n=len(a); alpha=q['confidence']; delta=.0025
                lo=max(1,int(binom.ppf(delta/2,n,alpha)))-1
                hi=min(n,int(binom.ppf(1-delta/2,n,alpha))+1)-1
                assert q['lower_index']==lo and q['upper_index']==hi
                close(q['var'],a[math.ceil(alpha*n)-1]); close(q['lower'],a[lo]); close(q['upper'],a[hi])
                close(q['coverage'],binom.cdf(hi,n,alpha)-binom.cdf(lo,n,alpha))
    print('Portfolio precision integrity/arithmetic passed'+(' including local arrays' if local else ' (no sample generation)'))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local',action='store_true')
    verify(parser.parse_args().local)
