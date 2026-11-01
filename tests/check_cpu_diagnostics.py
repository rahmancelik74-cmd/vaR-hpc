"""Verify real CPU stage accounting, numerical identity and CLI rejection."""
import json
import math
from pathlib import Path
import subprocess
import sys

exe=sys.argv[1]
root=Path(sys.argv[2])
configs=[['--backend','serial']]
if sys.argv[3]=='ON':configs += [['--backend','openmp','--threads',str(n)] for n in (1,2,4)]
for source in ([],['--csv',str(root/'data/synthetic_prices.csv')],['--portfolio',str(root/'data/portfolio-two.txt')]):
    reference=None
    for config in configs:
        args=[exe,*source,'10003','42',*config]
        plain=json.loads(subprocess.check_output([*args,'--json']))
        timed=json.loads(subprocess.check_output([*args,'--cpu-diagnostics','--json']))
        assert 'cpu_diagnostics' not in plain
        stages=timed.pop('cpu_diagnostics')
        values=[stages[key] for key in ('setup_ms','generation_ms','sorting_ms','quantile_ms','cleanup_ms')]
        assert stages['enabled'] and all(math.isfinite(v) and v>=0 for v in values)
        assert math.isclose(sum(values),timed['end_to_end_ms'],rel_tol=1e-10,abs_tol=1e-9)
        del plain['end_to_end_ms'];del timed['end_to_end_ms']
        assert plain==timed, 'Diagnostics changed numerical results or metadata'
        if timed['backend']=='openmp':
            estimates=timed['estimates']
            if reference is None:reference=estimates
            assert estimates==reference, 'Thread count changed native VaR'
for args in (['--cpu-diagnostics'],['--cpu-diagnostics','--cpu-diagnostics','--json'],
             ['--backend','cuda','--cpu-diagnostics','--json']):
    rejected=subprocess.run([exe,*args],capture_output=True,text=True)
    assert rejected.returncode and rejected.stderr and not rejected.stdout
print('CPU stage accounting, numerical identity, thread invariance and invalid CLI passed.')
