import csv, hashlib, json, re
from pathlib import Path
from PIL import Image, ImageChops
root = Path('.').resolve()
out = root / 'results/convergence-figure-closure-20261020-v2-final'
old = root / 'results/convergence-figures-390ffa6-20261020-final'
source = root / 'evidence/v030-convergence-windows-20261020'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
def csv_rows(p):
    with p.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))
p = read(out / 'plotted-data.json')
groups = {(r['engine'], int(r['scenarios']), float(r['confidence'])): r for r in csv_rows(source / 'summary.csv')}
seeds = {(r['engine'], int(r['scenarios']), r['seed'], float(r['confidence'])): r for r in csv_rows(source / 'per-seed.csv')}
accept = {(r['engine'], float(r['confidence'])): r for r in csv_rows(source / 'acceptance-10m.csv')}
assert (len(p['curves']), len(p['seed_series']), len(p['acceptance'])) == (24, 40, 8)
seen = set()
for r in p['curves']:
    key = r['engine'], r['alpha'], r['metric']
    assert key not in seen
    seen.add(key)
    assert r['N'] == [10000, 100000, 1000000, 10000000]
    for n, v in zip(r['N'], r['values']):
        assert v == float(groups[r['engine'], n, r['alpha']][r['metric']])
seen = set()
for r in p['seed_series']:
    key = r['engine'], r['alpha'], r['seed']
    assert key not in seen
    seen.add(key)
    for n, v in zip(r['N'], r['values']):
        assert v == float(seeds[r['engine'], n, r['seed'], r['alpha']]['signed_error'])
for r in p['acceptance']:
    row = accept[r['engine'], r['alpha']]
    assert r['ratio'] == float(row['absolute_error_of_mean']) / float(row['allowed_error'])
    assert r['absolute_error_of_mean'] == float(row['absolute_error_of_mean'])
    assert r['allowed_error'] == float(row['allowed_error'])
comparison = []
for new in sorted(out.glob('0*.png')):
    before, after = Image.open(old / new.name).convert('RGB'), Image.open(new).convert('RGB')
    assert before.size == after.size
    assert ImageChops.difference(before, after).getbbox() is None
    comparison.append({'figure': new.stem, 'size': list(after.size), 'pixels_equal_to_original': True})
pdf = (out / 'convergence_figures.pdf').read_bytes()
assert len(re.findall(rb'/Type /Page\b', pdf)) == 4
report = {'status': 'passed', 'comparison': 'Exact binary64 equality against verified CSVs',
          'curve_points': 96, 'signed_seed_points': 160, 'acceptance_points': 8,
          'png_comparison': comparison, 'combined_pdf_pages': 4,
          'new_simulation_processes': 0}
(root / 'results/convergence-figure-plotted-data-check-20261020.json').write_text(json.dumps(report, indent=2)+'\n', encoding='ascii')
print(json.dumps(report))
