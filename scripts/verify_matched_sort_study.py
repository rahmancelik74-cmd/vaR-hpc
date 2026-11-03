"""Independent arithmetic/coverage audit for the retained matched study."""
import csv,hashlib,json,math,statistics,sys
from pathlib import Path
p=Path(sys.argv[1]);m=json.loads((p/'manifest.json').read_text());assert m['status']=='completed'
raw=[json.loads(x) for x in (p/'runs.jsonl').read_text().splitlines()]
assert len(raw)==545
assert [x['sequence'] for x in raw]==list(range(1,546))
def value(r): return json.loads(json.loads(r['raw_stdout'])['stdout'])
rows=json.loads((p/'aggregate.json').read_text());assert len(rows)==39
for row in rows:
    c=[row['backend'],0 if row['backend']!='openmp' else row['generation_threads'],row['sort_team_bound'] if row['backend']=='openmp' and row in rows else 0,row['mode']]
    # Resolve serial-sort versus explicit one-worker sort from original ordered matrix.
    ix=rows.index(row)%13;c=m['configs'][ix]
    group=[r for r in raw if r['kind']=='primary' and r['n']==row['n'] and r['config']==c]
    for phase,count in [('warmup',3),('measured',10)]:assert sorted(r['repeat'] for r in group if r['phase']==phase)==list(range(1,count+1))
    xs=[value(r)['end_to_end_ms'] for r in group if r['phase']=='measured']
    assert math.isclose(sum(xs)/10,row['mean_ms'],rel_tol=1e-12)
    sd=math.sqrt(sum((x-sum(xs)/10)**2 for x in xs)/9)
    assert math.isclose(sd,row['sample_sd_ms'],rel_tol=1e-12)
    assert math.isclose(row['scenarios_per_second'],row['n']*1000/row['mean_ms'],rel_tol=1e-12)
    for r in group:assert value(r)['estimates']==value(group[0])['estimates']
for name,h in json.loads((p/'artifact-sha256.json').read_text()).items():assert hashlib.sha256((p/name).read_bytes()).hexdigest()==h
with (p/'aggregate.csv').open() as f:
    cs=list(csv.DictReader(f));assert len(cs)==39
    for a,b in zip(cs,rows):
        for k,v in b.items():assert a[k]==str(v)
print('PASS: 545 retained runs; 39 groups; coverage, deterministic estimates, means, sample SDs, throughput, CSV/JSON and exact-byte hashes')
