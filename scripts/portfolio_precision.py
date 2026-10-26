"""Post-campaign two-asset precision study. No production engine imports/runs.

Only 'reference' generates the fixed 80M samples; tests/verify never do so.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import warnings
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / 'evidence/portfolio-campaign-20261025'
PUBLIC = ROOT / 'evidence/portfolio-precision-20261025-v1'
LOCAL = ROOT / 'results/portfolio-precision-20261025-v1'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1048576), b''):
            h.update(b)
    return h.hexdigest()


def save(path, obj):
    Path(path).write_bytes((json.dumps(obj, indent=2, allow_nan=False) + '\n').encode('ascii'))


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def read_csv(path):
    with Path(path).open(newline='', encoding='ascii') as f:
        return list(csv.DictReader(f))


def fixture(path):
    t = Path(path).read_text(encoding='ascii').split()
    assert t[:1] == ['portfolio-v1'] and int(t[3]) == 2 and len(t) == 18
    a = [list(map(float, t[5+5*i:9+5*i])) for i in range(2)]
    r = list(map(float, t[14:]))
    assert r == [1., r[1], r[1], 1.] and abs(r[1]) < 1
    return dict(assets=a, horizon=float(t[2]), rho=r[1], initial=sum(x[0]*x[1] for x in a))


def terminal(f, eps):
    import numpy as np
    z0 = eps[:, 0]
    z1 = f['rho']*z0 + math.sqrt(1-f['rho']**2)*eps[:, 1]
    total = np.zeros(len(eps), dtype=np.float64)
    for (q, s, mu, sig), z in zip(f['assets'], (z0, z1)):
        total += q*(s*np.exp((mu-.5*sig*sig)*f['horizon']+sig*math.sqrt(f['horizon'])*z))
    if not np.isfinite(total).all():
        raise ArithmeticError('Nonfinite independent valuation')
    return total


def moments(f, order):
    # Binomial expansion of E[(X+Y)^k], joint Gaussian exponential MGF.
    (q, s, mu, sig), (r, t, nu, tau) = f['assets']
    return sum(math.comb(order, j)*(q*s)**j*(r*t)**(order-j)*math.exp(
        (j*(mu-.5*sig**2)+(order-j)*(nu-.5*tau**2)+.5*(j*j*sig**2+
        (order-j)**2*tau**2+2*j*(order-j)*sig*tau*f['rho']))*f['horizon']) for j in range(order+1))


def rank_interval(n, alpha, delta):
    from scipy.stats import binom
    lower = max(1, int(binom.ppf(delta/2, n, alpha)))
    upper = min(n, int(binom.ppf(1-delta/2, n, alpha))+1)
    coverage = float(binom.cdf(upper-1, n, alpha)-binom.cdf(lower-1, n, alpha))
    if coverage < 1-delta-1e-12:
        raise ArithmeticError('Insufficient binomial coverage')
    return lower-1, upper-1, coverage


def classify(mean, lower, upper, target):
    if upper-lower > target:
        return 'inconclusive'
    if max(abs(mean-lower), abs(mean-upper)) <= target:
        return 'pass'
    if max(lower-mean, mean-upper, 0.) > target:
        return 'fail'
    return 'inconclusive'


def frozen():
    p = load(PUBLIC/'protocol-v1.json')
    for name, value in load(PUBLIC/'freeze-v1.json').items():
        if sha(ROOT/name) != value:
            raise ValueError('Frozen input/source changed: '+name)
    assert p['samples_per_fixture'] == p['hard_sample_ceiling_per_fixture'] == 80000000
    return p


def freeze():
    PUBLIC.mkdir(exist_ok=False)
    old = load(OLD/'protocol-v1.json')
    p = dict(version=1, study='New post-campaign precision follow-up; original frozen study unchanged',
        created_utc=datetime.now(timezone.utc).isoformat(),
        fixtures={k:old['fixtures'][k] for k in ('two-negative', 'two-positive')},
        seeds={'two-negative': 1749202601, 'two-positive': 1749202602},
        seed_policy='Fresh explicit labels disjoint from old reference/native/check streams; no seed search. PRNG independence is a modeling assumption.',
        samples_per_fixture=80000000, hard_sample_ceiling_per_fixture=80000000,
        chunk_size=250000, rng='NumPy PCG64DXSM Generator.standard_normal float64, scenario-major two normals',
        construction='Z1=e1; Z2=rho*e1+sqrt(1-rho^2)*e2. Ordered original asset parameters; q*(S0*exp(...)), V0-sum(VT); no production helpers.',
        quantile='Global ascending scalar losses; zero-based ceil(alpha*M)-1; no interpolation, chunk quantiles or clipping.',
        confidence=[.95, .99], family_error=.01, interval_count=4, per_interval_error=.0025,
        interval='Binomial central rank interval: l=max(1,ppf(delta/2)); u=min(M,ppf(1-delta/2)+1); [loss[l-1],loss[u-1]]. Check actual coverage >=1-delta.',
        coverage_scope='At least 99% simultaneous coverage of FOUR new reference quantiles under continuous ideal-iid model, Bonferroni. Reused observed means are fixed comparisons. Separate from original study coverage; NO combined 99% claim.',
        practical_target_fraction_V0=.0005,
        practical_rule='Pass max(|m-L|,|m-U|)<=target; fail distance(m,[L,U])>target; else inconclusive. Half-width>target/2 overrides to inconclusive. Realized five-seed means only, not population means.',
        reuse='All twelve two-asset N=10M rows from original convergence.csv and original validation-raw.csv; verify means, five seeds and original input bytes. No native execution. Original Beta/DKW/statistical and five-identity records unchanged.',
        resource_policy='Sequential fixtures; each NPY 640000128 bytes; two retained files about 1.28GB; in-place sort(kind=quicksort), 250k chunks, no full normal matrix. OS mapped pages may use ~640MB per fixture plus chunks. Require 2GB free disk; no external processes/parallel fixtures.',
        failure_policy='One attempt per fixture; exclusive directory creation; no reruns, extensions, seed changes or threshold relaxation. Preserve partial arrays and error record on failure/interruption. Hard wall ceiling 3600s TOTAL reference generation; check per chunk/before and after sort. One uninterruptible sort may overrun; reject if elapsed exceeds ceiling. No five-asset generation.',
        numerical_method='Condition on first standard normal; integrate phi(z)*Phi((log(s-X(z))-b2-rho*c2*z)/(c2*sqrt(1-rho^2))) for X<s; invert CDF(s)=1-alpha by bracketed brentq. Stable log remainder via log(s)+log(-expm1(log(X)-log(s))).',
        numerical_controls='Primary z in [-10,10], adaptive quad split every 1 and at log(s) crossing. epsabs=epsrel=2e-11; root xtol=1e-9 rtol=1e-13. Check swapped asset order; tight [-12,12], eps=2e-13 xtol=1e-11; alternative u=Phi(z) integral on [0,Phi(crossing)] with probability partitions. Reject all IntegrationWarnings/nonfinite values/bracketing failures. Handle T=0 and zero vol analytically.',
        numerical_error='Record quadrature error estimates and analytic omitted Gaussian tail <=2*Phi(-B); propagate estimated CDF error by inversion at p +/- (max root quadrature estimate + tail + residual), report root spread and tolerance. Error estimates/spread are empirical diagnostics, NOT rigorous certified bounds. Numerical results corroborate only and NEVER determine practical classification.',
        numerical_validation='Known deterministic and single-random-asset reductions; explicit small normal scenarios; exact first/second/fourth moments; swap assets, tighter tolerances and probability transformation. No production imports, no five-dimensional integration.',
        hard_numerical_ceiling='Four modes per quantile, four fixture/confidence pairs; at most 120s per quadrature call and 100 root iterations; stop and record errors on failure.',
        source_head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
    save(PUBLIC/'protocol-v1.json',p)
    paths = [PUBLIC/'protocol-v1.json', Path(__file__)]
    paths += list(OLD.rglob('*'))
    save(PUBLIC/'freeze-v1.json', {x.relative_to(ROOT).as_posix():sha(x) for x in paths if x.is_file()})
    print('Frozen', sha(PUBLIC/'protocol-v1.json'))


def references():
    import numpy as np
    import scipy
    p = frozen()
    LOCAL.mkdir(exist_ok=False)
    if shutil.disk_usage(LOCAL).free < 2000000000:
        raise OSError('Need 2GB free disk')
    start = time.perf_counter()
    result = dict(status='running', started_utc=datetime.now(timezone.utc).isoformat(),
        command=sys.argv, source_head=p['source_head'], source_exact_sha256=sha(__file__),
        protocol_sha256=sha(PUBLIC/'protocol-v1.json'), freeze_sha256=sha(PUBLIC/'freeze-v1.json'),
        platform=platform.platform(), python=sys.version, executable=sys.executable,
        executable_sha256=sha(sys.executable), numpy=np.__version__, scipy=scipy.__version__,
        numpy_init_sha256=sha(np.__file__), scipy_init_sha256=sha(scipy.__file__),
        source_git_blob='New uncommitted script at execution; exact bytes frozen before samples; not a HEAD blob.',
        cases={}, errors=[])
    save(PUBLIC/'reference.json', result)
    try:
        for name, item in p['fixtures'].items():
            t0 = time.perf_counter()
            f = fixture(ROOT/item['path']); n = p['samples_per_fixture']
            path = LOCAL/(name+'.npy')
            losses = np.lib.format.open_memmap(path, mode='w+', dtype=np.float64, shape=(n,))
            rng = np.random.Generator(np.random.PCG64DXSM(p['seeds'][name]))
            sums = [0., 0.]
            for offset in range(0, n, p['chunk_size']):
                if time.perf_counter()-start > 3600:
                    raise TimeoutError('Reference wall ceiling')
                count = min(p['chunk_size'], n-offset)
                vt = terminal(f, rng.standard_normal((count, 2), dtype=np.float64))
                losses[offset:offset+count] = f['initial']-vt
                sums[0] += float(np.sum(vt)); sums[1] += float(np.sum(vt*vt))
            losses.sort(kind='quicksort')
            if time.perf_counter()-start > 3600:
                raise TimeoutError('Reference sort exceeded wall ceiling')
            quantiles=[]
            for alpha in p['confidence']:
                lo, hi, coverage = rank_interval(n, alpha, p['per_interval_error'])
                quantiles.append(dict(confidence=alpha, var=float(losses[math.ceil(alpha*n)-1]),
                    lower=float(losses[lo]), upper=float(losses[hi]), lower_index=lo, upper_index=hi,
                    coverage=coverage, width=float(losses[hi]-losses[lo])))
            losses.flush(); del losses
            mean = sums[0]/n
            m1, m2, m4 = [moments(f,k) for k in (1,2,4)]
            result['cases'][name]=dict(fixture=item, seed=p['seeds'][name], scenarios=n,
                initial_value=f['initial'], quantiles=quantiles, array_path=path.relative_to(ROOT).as_posix(),
                array_sha256=sha(path), array_bytes=path.stat().st_size,
                sample_terminal_mean=mean, sample_terminal_second_moment=sums[1]/n,
                exact_terminal_mean=m1, exact_terminal_second_moment=m2,
                mean_standard_error=math.sqrt((m2-m1*m1)/n),
                second_moment_standard_error=math.sqrt((m4-m2*m2)/n),
                duration_seconds=time.perf_counter()-t0)
            save(PUBLIC/'reference.json',result)
            print('80M complete',name,flush=True)
        result['status']='complete'
    except BaseException as e:
        result['status']='interrupted_or_failed'; result['errors'].append(repr(e)); raise
    finally:
        result['duration_seconds']=time.perf_counter()-start
        save(PUBLIC/'reference.json',result)


def cdf(f, s, mode='primary'):
    """Conditional terminal-sum CDF; separate scalar math from MC valuation."""
    from scipy.integrate import quad, IntegrationWarning
    from scipy.special import ndtr, ndtri
    if s <= 0:
        return 0., 0., 0.
    a = f['assets']; T=f['horizon']; rho=f['rho']
    b = [math.log(q*price)+(mu-.5*sig*sig)*T for q,price,mu,sig in a]
    c = [row[3]*math.sqrt(T) for row in a]
    if not any(c):
        return float(s >= sum(math.exp(x) for x in b)),0.,0.
    if not all(c):
        i=0 if c[0] else 1; j=1-i
        remainder=s-math.exp(b[j])
        return (float(ndtr((math.log(remainder)-b[i])/c[i])) if remainder>0 else 0.),0.,0.
    crossing=(math.log(s)-b[0])/c[0]
    scale=c[1]*math.sqrt(1-rho*rho)
    def conditional(z):
        d=b[0]+c[0]*z-math.log(s)
        if d >= 0:
            return 0.
        log_remaining=math.log(s)+math.log(-math.expm1(d))
        return float(ndtr((log_remaining-b[1]-rho*c[1]*z)/scale))
    tol=2e-13 if mode=='tight' else 2e-11
    start=time.perf_counter()
    def timed(z):
        if time.perf_counter()-start > 120:
            raise TimeoutError('Quadrature call ceiling')
        return conditional(z)
    if mode=='probability':
        upper=float(ndtr(crossing))
        points=sorted(set([0.,upper]+[u for u in (1e-8,1e-6,.0001,.001,.01,.05,.1,.25,.5,.75,.9,.99,.9999) if u<upper]))
        fn=lambda u: timed(float(ndtri(u)))
        tail=0.
    else:
        B=12 if mode=='tight' else 10
        upper=min(B,crossing)
        if upper <= -B:
            return 0.,0.,2*float(ndtr(-B))
        points=sorted(set([-float(B),upper]+[float(z) for z in range(-B+1,B) if z<upper]))
        fn=lambda z: timed(z)*math.exp(-z*z/2)/math.sqrt(2*math.pi)
        tail=2*float(ndtr(-B))
    value=error=0.
    with warnings.catch_warnings():
        warnings.simplefilter('error',IntegrationWarning)
        for left,right in zip(points,points[1:]):
            v,e=quad(fn,left,right,epsabs=tol/max(1,len(points)-1),epsrel=tol,limit=250)
            value+=v; error+=e
    if not math.isfinite(value+error):
        raise ArithmeticError('Nonfinite CDF')
    return value,error,tail


def numerical_quantile(f, alpha, mode='primary'):
    from scipy.optimize import brentq
    p=1-alpha
    lo=0.; hi=2*f['initial']; expansions=0
    while cdf(f,hi,mode)[0]<p:
        hi*=2; expansions+=1
        if expansions>30:
            raise ArithmeticError('Failed quantile bracket')
    tol=1e-11 if mode=='tight' else 1e-9
    root, info=brentq(lambda s:cdf(f,s,mode)[0]-p,lo,hi,xtol=tol,rtol=1e-13,maxiter=100,full_output=True)
    if not info.converged:
        raise ArithmeticError('Root did not converge')
    value,err,tail=cdf(f,root,mode)
    budget=err+tail+abs(value-p)
    ends=[brentq(lambda s:cdf(f,s,mode)[0]-level,lo,hi,xtol=tol,rtol=1e-13,maxiter=100)
          for level in (max(1e-15,p-budget),min(1-1e-15,p+budget))]
    return dict(var=f['initial']-root, terminal_quantile=root, cdf=value,
        quadrature_error_estimate=err, omitted_tail_bound=tail, cdf_residual=abs(value-p),
        estimated_cdf_error_budget=budget, propagated_quantile_error_estimate=max(abs(x-root) for x in ends),
        root_xtol=tol, root_rtol=1e-13, iterations=info.iterations, bracket_expansions=expansions)


def numerical():
    p=frozen()
    if (PUBLIC/'numerical.json').exists():
        raise FileExistsError('Numerical attempt already recorded')
    result=dict(status='running', command=sys.argv, cases={}, errors=[],
        interpretation='Corroboration only. QUADPACK error estimates and mode agreement are not certified enclosures.')
    t0=time.perf_counter()
    try:
        for name,item in p['fixtures'].items():
            f=fixture(ROOT/item['path']); result['cases'][name]=[]
            for alpha in p['confidence']:
                modes={m:numerical_quantile(f,alpha,m) for m in ('primary','tight','probability')}
                swapped=dict(f,assets=list(reversed(f['assets'])))
                modes['swapped']=numerical_quantile(swapped,alpha)
                spread=max(x['var'] for x in modes.values())-min(x['var'] for x in modes.values())
                result['cases'][name].append(dict(confidence=alpha,modes=modes,mode_spread=spread,
                    assessment='Empirical stability only; no rigorous total floating-point/quadrature bound.'))
            print('Numerical complete',name,flush=True)
        result['status']='complete'
    except BaseException as e:
        result['status']='failed'; result['errors'].append(repr(e)); raise
    finally:
        result['duration_seconds']=time.perf_counter()-t0
        save(PUBLIC/'numerical.json',result)


def reassess():
    p=frozen(); ref=load(PUBLIC/'reference.json'); num=load(PUBLIC/'numerical.json')
    assert ref['status']==num['status']=='complete'
    native=read_csv(OLD/'validation-raw.csv'); rows=[]
    for old in read_csv(OLD/'convergence.csv'):
        if old['fixture'] not in p['fixtures'] or int(old['scenarios'])!=10000000:
            continue
        name=old['fixture']; alpha=float(old['confidence'])
        values=[float(r['var'+str(round(alpha*100))]) for r in native if all(r[k]==old[k] for k in ('fixture','scenarios','config'))]
        seeds=[int(r['seed']) for r in native if all(r[k]==old[k] for k in ('fixture','scenarios','config'))]
        assert sorted(seeds)==load(OLD/'protocol-v1.json')['validation_seeds']
        mean=sum(values)/5
        assert math.isclose(mean,float(old['mean_var']),abs_tol=1e-12,rel_tol=0)
        q=next(q for q in ref['cases'][name]['quantiles'] if q['confidence']==alpha)
        numerical=next(x for x in num['cases'][name] if x['confidence']==alpha)
        target=float(old['practical_target'])
        assert target==p['practical_target_fraction_V0']*ref['cases'][name]['initial_value']
        new=classify(mean,q['lower'],q['upper'],target)
        rows.append(dict(fixture=name,config=old['config'],confidence=alpha,scenarios=10000000,
            mean_var=old['mean_var'],old_status=old['practical'],old_reference=old['reference'],
            old_lower=old['reference_lower'],old_upper=old['reference_upper'],
            reference=q['var'],lower=q['lower'],upper=q['upper'],new_width=q['width'],
            numerical_var=numerical['modes']['primary']['var'],numerical_mode_spread=numerical['mode_spread'],
            numerical_propagated_error_estimate=numerical['modes']['primary']['propagated_quantile_error_estimate'],
            numerical_error_scope='Estimated, not certified; corroboration only',
            practical_target=target,worst_error=max(abs(mean-q['lower']),abs(mean-q['upper'])),
            new_status=new,reason='New independent reference and narrower rank interval; unchanged native observations and target' if old['practical']!=new else 'Same decision with new independent reference'))
    assert len(rows)==12 and sum(x['old_status']=='inconclusive' for x in rows)==9
    with (PUBLIC/'reassessment.csv').open('w',newline='',encoding='ascii') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    save(PUBLIC/'completion.json',dict(status='local_calculations_complete',
        endpoint_totals={s:sum(x['new_status']==s for x in rows) for s in ('pass','fail','inconclusive')},
        previously_inconclusive_totals={s:sum(x['new_status']==s and x['old_status']=='inconclusive' for x in rows) for s in ('pass','fail','inconclusive')},
        five_identity='Original six pass outcomes and 20M reference unchanged; not part of follow-up coverage family.',
        original_study='9/18 pass, 9/18 inconclusive, 0 fail unchanged; Beta/DKW unchanged',
        coverage=p['coverage_scope'], delivery='Pending; local completion is not commit/push/CI evidence'))
    print(json.dumps(load(PUBLIC/'completion.json')['endpoint_totals']))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['freeze','reference','numerical','reassess'])
    action=parser.parse_args().action
    globals()[{'reference':'references'}.get(action,action)]()


if __name__=='__main__':
    main()
