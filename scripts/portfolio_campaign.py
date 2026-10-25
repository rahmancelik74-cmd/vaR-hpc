"""Frozen synthetic portfolio campaigns; no production numerical code is changed.

NumPy/SciPy are required only for reference/analysis, not the application or runner.
All campaign processes are sequential. Public CSVs retain every successful sample;
full launch records and reference arrays live in the ignored local directory.
"""
import argparse
import csv
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "evidence/portfolio-campaign-20261025"
LOCAL = ROOT / "results/portfolio-campaign-20261025"
BUILD = ROOT / "build-portfolio-campaign-20261025"
ALPHAS = (.95, .99)


def sha(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024*1024), b""):
            value.update(block)
    return value.hexdigest()


def save(path, obj):
    Path(path).write_text(json.dumps(obj, indent=2, allow_nan=False) + "\n", encoding="ascii")


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def frozen():
    ledger = load(PUBLIC / "freeze-v1.json")
    for name in ("PROTOCOL-v1.md", "protocol-v1.json"):
        if sha(PUBLIC / name) != ledger[name]:
            raise ValueError("Frozen protocol changed: " + name)
    protocol = load(PUBLIC / "protocol-v1.json")
    for item in protocol["fixtures"].values():
        if sha(ROOT / item["path"]) != item["sha256"]:
            raise ValueError("Frozen fixture bytes changed")
    return protocol


def fixture(path):
    tokens = Path(path).read_text(encoding="ascii").split()
    n = int(tokens[3])
    if tokens[0] != "portfolio-v1" or not 1 <= n <= 5 or len(tokens) != 4+5*n+n*n:
        raise ValueError("Unsupported oracle fixture")
    assets = [list(map(float, tokens[5+5*i:9+5*i])) for i in range(n)]
    matrix = list(map(float, tokens[4+5*n:]))
    if n == 2:
        rho = matrix[1]
        if matrix != [1., rho, rho, 1.] or abs(rho) >= 1:
            raise ValueError("Oracle supports explicit nonsingular two-asset factor")
    elif any(matrix[i*n+j] != (1. if i == j else 0.) for i in range(n) for j in range(n)):
        raise ValueError("Oracle supports identity outside two-asset fixtures")
    return dict(unit=tokens[1], horizon=float(tokens[2]), assets=assets, matrix=matrix,
                initial=sum(q*s for q, s, _, _ in assets))


def terminal(f, epsilon):
    import numpy as np
    n = len(f["assets"])
    vt = np.zeros(len(epsilon), dtype=np.float64)
    for i, (quantity, price, drift, sigma) in enumerate(f["assets"]):
        z = epsilon[:, i]
        if n == 2 and i == 1:
            rho = f["matrix"][1]
            z = rho*epsilon[:, 0] + math.sqrt(1-rho*rho)*epsilon[:, 1]
        vt += quantity * (price*np.exp((drift-sigma*sigma/2)*f["horizon"]
                                      + sigma*math.sqrt(f["horizon"])*z))
    if not np.isfinite(vt).all():
        raise ArithmeticError("Reference valuation overflow")
    return vt


def moment(f, order):
    """Joint lognormal MGF expanded over ordered asset index tuples."""
    a = f["assets"]
    n = len(a)
    total = 0.
    for indices in itertools.product(range(n), repeat=order):
        counts = [indices.count(i) for i in range(n)]
        coefficient = math.prod((a[i][0]*a[i][1])**counts[i] for i in range(n))
        exponent = sum(counts[i]*(a[i][2]-a[i][3]**2/2) for i in range(n))
        exponent += .5*sum(counts[i]*counts[j]*a[i][3]*a[j][3]*f["matrix"][i*n+j]
                            for i in range(n) for j in range(n))
        total += coefficient*math.exp(exponent*f["horizon"])
    return total


def order_interval(n, alpha, delta):
    from scipy.stats import binom
    lo = max(1, int(binom.ppf(delta/2, n, alpha)))
    hi = min(n, int(binom.ppf(1-delta/2, n, alpha))+1)
    coverage = float(binom.cdf(hi-1, n, alpha)-binom.cdf(lo-1, n, alpha))
    if coverage + 1e-12 < 1-delta:
        raise ArithmeticError("Binomial interval undercoverage")
    return lo-1, hi-1, coverage


def oracle_checks(protocol):
    import numpy as np
    from scipy.stats import norm
    from statistics import NormalDist
    f = dict(horizon=1., assets=[[1., 100., .05, .2]], matrix=[1.], initial=100.)
    for alpha in ALPHAS:
        actual = float(100-terminal(f, np.array([[norm.ppf(1-alpha)]]))[0])
        expected = 100*(1-math.exp(.03+.2*NormalDist().inv_cdf(1-alpha)))
        assert abs(actual-expected) <= 1e-10
    f["horizon"] = 0
    assert float(terminal(f, np.array([[20.]]))[0]) == 100
    f["horizon"] = 1; f["assets"][0][3] = 0
    value = float(100-terminal(f, np.zeros((1, 1)))[0])
    assert value < 0 and abs(value-100*(1-math.exp(.05))) < 1e-10
    f = fixture(ROOT / protocol["fixtures"]["two-positive"]["path"])
    eps = np.array([[1., 0.], [0., 1.], [-1., 2.], [0., 0.]])
    expected = []
    for x, y in eps:
        z = (x, .6*x+.8*y)
        expected.append(sum(q*s*math.exp((mu-sigma*sigma/2)+sigma*z[i])
                            for i, (q, s, mu, sigma) in enumerate(f["assets"])))
    assert np.max(np.abs(terminal(f, eps)-expected)) < 1e-10
    losses = f["initial"]-terminal(f, eps)
    assert np.quantile(losses, .95, method="inverted_cdf") == max(losses)
    c = np.array([[1., 0.], [.6, .8]])
    assert np.max(abs(c @ c.T-np.array([[1, .6], [.6, 1]]))) < 1e-14
    checks = []
    rng = np.random.Generator(np.random.PCG64DXSM(778899))
    for item in protocol["fixtures"].values():
        f = fixture(ROOT/item["path"])
        vt = terminal(f, rng.standard_normal((100000, len(f["assets"]))))
        m1, m2, m4 = (moment(f, k) for k in (1, 2, 4))
        for observed, expected, variance in [(float(vt.mean()), m1, m2-m1*m1),
                                              (float(np.mean(vt*vt)), m2, m4-m2*m2)]:
            bound = math.sqrt(variance*6/(100000*.01))
            assert abs(observed-expected) <= bound
            checks.append(dict(observed=observed, expected=expected, bound=bound))
    return dict(status="passed", analytical_deterministic_small_factor_checks=True,
                moment_seed=778899, moment_checks=checks)


def snapshot():
    paths = sorted(list((ROOT/"src").glob("*"))+list((ROOT/"include").rglob("*.hpp"))
                   +list((ROOT/"include").rglob("*.in"))+[ROOT/"CMakeLists.txt", ROOT/"tools/cpu_probe.cpp"])
    result = {}
    for p in paths:
        name = p.relative_to(ROOT).as_posix()
        blob = subprocess.check_output(["git", "show", "HEAD:"+name], cwd=ROOT)
        result[name] = dict(local_exact_sha256=sha(p), git_normalized_blob_sha256=hashlib.sha256(blob).hexdigest())
    return result


def environment():
    env = os.environ.copy()
    for key in ("OMP_NUM_THREADS", "OMP_DYNAMIC", "OMP_NESTED", "OMP_SCHEDULE", "OMP_PROC_BIND",
                "OMP_PLACES", "OMP_THREAD_LIMIT", "OMP_WAIT_POLICY", "KMP_AFFINITY", "KMP_BLOCKTIME", "GOMP_CPU_AFFINITY"):
        env.pop(key, None)
    env.update(OMP_DYNAMIC="FALSE", OMP_NESTED="FALSE", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1")
    return env


def gpu_observation():
    cmd = ["nvidia-smi", "--query-gpu=name,driver_version,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,pstate", "--format=csv"]
    p = subprocess.run(cmd, capture_output=True, timeout=15)
    return dict(utc=datetime.now(timezone.utc).isoformat(), exit_code=p.returncode,
                stdout=p.stdout.decode(errors="replace"), stderr=p.stderr.decode(errors="replace"),
                scope="point observation, not thermal equilibrium or continuous telemetry")


def references():
    import numpy as np
    import scipy
    p = frozen()
    destination = LOCAL/"reference"
    destination.mkdir(exist_ok=False)
    save(PUBLIC/"oracle-checks.json", oracle_checks(p))
    summary = dict(status="running", numpy=np.__version__, scipy=scipy.__version__, python=sys.version,
                   python_executable_sha256=sha(sys.executable), numpy_module_sha256=sha(np.__file__), scipy_module_sha256=sha(scipy.__file__),
                   platform=platform.platform(), oracle_sha256=sha(__file__), cases={})
    save(PUBLIC/"reference.json", summary)
    for name, item in p["fixtures"].items():
        f = fixture(ROOT/item["path"])
        n = p["reference"]["scenarios"]
        if n < 1 or n > 20000000 or n*8 > 160000000:
            raise ValueError("Reference resource limit")
        path = destination/(name+".npy")
        losses = np.lib.format.open_memmap(path, mode="w+", dtype=np.float64, shape=(n,))
        rng = np.random.Generator(np.random.PCG64DXSM(p["reference"]["seeds"][name]))
        sums = [0., 0.]
        for start in range(0, n, p["reference"]["chunk_size"]):
            count = min(p["reference"]["chunk_size"], n-start)
            vt = terminal(f, rng.standard_normal((count, len(f["assets"]))))
            losses[start:start+count] = f["initial"]-vt
            sums[0] += float(np.sum(vt)); sums[1] += float(np.sum(vt*vt))
        losses.sort()
        estimates = np.quantile(losses, ALPHAS, method="inverted_cdf")
        case = dict(fixture=item, initial_value=f["initial"], assets=len(f["assets"]), scenarios=n,
                    seed=p["reference"]["seeds"][name], sample_terminal_mean=sums[0]/n,
                    sample_terminal_variance=(sums[1]/n-(sums[0]/n)**2)*n/(n-1),
                    exact_terminal_mean=moment(f, 1), exact_terminal_variance=moment(f, 2)-moment(f, 1)**2,
                    quantiles=[])
        for alpha, estimate in zip(ALPHAS, estimates):
            lo, hi, coverage = order_interval(n, alpha, .0025/6)
            case["quantiles"].append(dict(confidence=alpha, var=float(estimate), lower=float(losses[lo]),
                upper=float(losses[hi]), lower_index=lo, upper_index=hi, coverage=coverage,
                dkw_epsilon=math.sqrt(math.log(2/(.0025/3))/(2*n))))
        losses.flush(); del losses
        case["array_sha256"] = sha(path)
        summary["cases"][name] = case
        save(PUBLIC/"reference.json", summary)
        print("reference complete", name, flush=True)
    summary["status"] = "complete"
    save(PUBLIC/"reference.json", summary)


def power_key(power):
    return tuple(power[k] for k in ("ac_line_status", "battery_saver", "active_power_scheme"))


def run_campaign():
    p = frozen()
    if load(PUBLIC/"reference.json")["status"] != "complete":
        raise ValueError("Reference must finish before native campaigns")
    records = LOCAL/"processes"
    records.mkdir(exist_ok=False)
    env = environment()
    exe = BUILD/"mc_var.exe"; probe = BUILD/"mc_cpu_probe.exe"
    inventory = json.loads(subprocess.check_output([str(probe), "--inventory"], env=env))
    save(PUBLIC/"machine-inventory.json", inventory)
    mask = inventory["process_mask_hex"]
    original = snapshot()
    artifacts = {p.relative_to(ROOT).as_posix():sha(p) for p in sorted(BUILD.iterdir())
                 if p.is_file() and (p.suffix.lower() in (".exe", ".dll") or p.name in ("CMakeCache.txt", "build.ninja"))}
    manifest = dict(status="running", started_utc=datetime.now(timezone.utc).isoformat(),
        head=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        git_status=subprocess.check_output(["git", "status", "--short"], text=True).splitlines(),
        source_snapshot=original, artifacts=artifacts, runner_sha256=sha(__file__),
        protocol_sha256=sha(PUBLIC/"protocol-v1.json"), executable=exe.relative_to(ROOT).as_posix(),
        provenance="New dedicated x64 Ninja Release build observed in local build.log; production exact bytes and Git-normalized bytes distinguished; tooling uncommitted; not independent source-to-binary proof",
        process_policy=p["benchmark"]["process"], timing=p["benchmark"]["timer"],
        physical_conditions="User absent; surface/cooling/vendor fan/ambient unknown; CPU temperature unmeasured; no equilibrium assertion or setting changes",
        env_policy="OMP_DYNAMIC=FALSE OMP_NESTED=FALSE; other listed OMP/affinity variables unset in child; BLAS thread caps1",
        compiler_flags=[s for s in (BUILD/"CMakeCache.txt").read_text().splitlines() if s.startswith(("CMAKE_CXX_FLAGS", "CMAKE_CUDA_FLAGS", "CMAKE_CUDA_ARCHITECTURES", "OpenMP_CXX_FLAGS"))],
        native_metadata={}, gpu_observations=[gpu_observation()], errors=[])
    save(PUBLIC/"manifest.json", manifest)
    number = 0
    fields = ["id", "fixture", "assets", "scenarios", "config", "backend", "seed", "phase", "repetition", "end_to_end_ms", "threads_used", "var95", "var99", "record_sha256"]

    def sample(name, n, config, seed, phase, repetition, writer, handle):
        nonlocal number
        number += 1
        args = [str(exe), "--portfolio", p["fixtures"][name]["path"], str(n), str(seed)]
        backend = "openmp" if config.startswith("openmp") else config
        args += ["--backend", backend]
        if backend == "openmp": args += ["--threads", config[6:]]
        if backend == "cuda": args += ["--cuda-mode", "full-device"]
        args += ["--json"]
        started = datetime.now(timezone.utc).isoformat()
        completed = subprocess.run([str(probe), "--run-timeout", "120000", mask, *args],
                                   capture_output=True, env=env, timeout=135)
        raw = dict(utc=started, command=args, probe_exit=completed.returncode,
                   stdout=completed.stdout.decode(errors="replace"), stderr=completed.stderr.decode(errors="replace"))
        path = records/(f"{number:04d}.json")
        save(path, raw)
        if completed.returncode:
            raise RuntimeError("Probe failed: " + path.as_posix())
        launch = json.loads(completed.stdout)
        if launch["exit_code"] or launch["timed_out"] or launch["stderr"]:
            raise RuntimeError("Native sample failed: " + path.as_posix())
        if phase != "validation" and (power_key(launch["before"]) != power_key(inventory["power"]) or
                                      power_key(launch["after"]) != power_key(inventory["power"])):
            raise RuntimeError("Power conditions changed; preserve attempt")
        result = json.loads(launch["stdout"])
        if backend not in manifest["native_metadata"]:
            manifest["native_metadata"][backend] = {key:result[key] for key in ("backend", "random_source", "openmp_version", "cuda")}
        if result["input_mode"] != "portfolio" or result["backend"] != backend or "common" in result["random_source"]:
            raise RuntimeError("Wrong execution path")
        if backend == "openmp" and result["threads_used"] != int(config[6:]):
            raise RuntimeError("OpenMP team mismatch")
        if not math.isfinite(result["end_to_end_ms"]) or result["end_to_end_ms"] <= 0:
            raise RuntimeError("Invalid primary time")
        row = dict(id=number, fixture=name, assets=len(result["portfolio"]["assets"]), scenarios=n, config=config,
            backend=backend, seed=seed, phase=phase, repetition=repetition, end_to_end_ms=result["end_to_end_ms"],
            threads_used=result["threads_used"], var95=result["estimates"][0]["mc_var"], var99=result["estimates"][1]["mc_var"], record_sha256=sha(path))
        writer.writerow(row); handle.flush()
        time.sleep(.1)

    try:
        with (PUBLIC/"validation-raw.csv").open("x", newline="", encoding="ascii") as file:
            writer = csv.DictWriter(file, fields); writer.writeheader()
            for name in p["fixtures"]:
                for n in p["scenario_grid"]:
                    for config in p["validation_engines"]:
                        for seed in p["validation_seeds"]:
                            sample(name, n, config, seed, "validation", 0, writer, file)
                    print("native validation", name, n, flush=True)
        with (PUBLIC/"benchmark-raw.csv").open("x", newline="", encoding="ascii") as file:
            writer = csv.DictWriter(file, fields); writer.writeheader()
            for name in p["benchmark"]["fixtures"]:
                for n in p["scenario_grid"]:
                    manifest["gpu_observations"].append(gpu_observation())
                    for phase, count in [("warmup", 3), ("measured", 10)]:
                        for rep in range(count):
                            configs = p["benchmark"]["configurations"][:]
                            if rep % 2: configs.reverse()
                            shift = (3*rep) % len(configs)
                            configs = configs[shift:]+configs[:shift]
                            for config in configs:
                                sample(name, n, config, 42, phase, rep, writer, file)
                    print("benchmark", name, n, flush=True)
        if snapshot() != original or any(sha(ROOT/name) != value for name, value in artifacts.items()):
            raise RuntimeError("Source/build changed during campaign")
        manifest["status"] = "complete"
        manifest["processes"] = number
    except BaseException as error:
        manifest["status"] = "failed"
        manifest["errors"].append(repr(error))
        raise
    finally:
        manifest["gpu_observations"].append(gpu_observation())
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save(PUBLIC/"manifest.json", manifest)


def read_rows(name):
    with (PUBLIC/name).open(newline="", encoding="ascii") as file:
        return list(csv.DictReader(file))


def write_rows(name, rows):
    with (PUBLIC/name).open("w", newline="", encoding="ascii") as file:
        writer = csv.DictWriter(file, list(rows[0])); writer.writeheader(); writer.writerows(rows)


def practical(mean, lo, hi, target):
    worst = max(abs(mean-lo), abs(mean-hi))
    best = max(lo-mean, mean-hi, 0.)
    status = "pass" if worst <= target else "fail" if best > target else "inconclusive"
    if (hi-lo)/2 > target/2: status = "inconclusive"
    return status, worst, best


def analyze():
    import numpy as np
    from scipy.stats import beta
    p = frozen(); ref = load(PUBLIC/"reference.json")
    validation = read_rows("validation-raw.csv")
    details, summary = [], []
    for name in p["fixtures"]:
        case = ref["cases"][name]
        array = np.load(LOCAL/"reference"/(name+".npy"), mmap_mode="r")
        for n in p["scenario_grid"]:
            for config in p["validation_engines"]:
                group = [r for r in validation if r["fixture"] == name and int(r["scenarios"]) == n and r["config"] == config]
                if len(group) != 5: raise ValueError("Incomplete native group")
                for alpha, q in zip(ALPHAS, case["quantiles"]):
                    values = []
                    rejected = 0
                    k = math.ceil(alpha*n)
                    probability_lo, probability_hi = beta.ppf([.005/(2*270), 1-.005/(2*270)], k, n+1-k)
                    for r in group:
                        value = float(r["var"+str(round(alpha*100))]); values.append(value)
                        empirical = int(np.searchsorted(array, value, side="right"))/len(array)
                        consistent = probability_lo-q["dkw_epsilon"] <= empirical <= probability_hi+q["dkw_epsilon"]
                        rejected += not consistent
                        details.append(dict(fixture=name, scenarios=n, config=config, confidence=alpha, seed=r["seed"],
                            var=value, reference=q["var"], signed_error=value-q["var"], absolute_error=abs(value-q["var"]),
                            reference_lower=q["lower"], reference_upper=q["upper"], reference_empirical_cdf=empirical,
                            cdf_lower=float(probability_lo-q["dkw_epsilon"]), cdf_upper=float(probability_hi+q["dkw_epsilon"]),
                            consistency="not_rejected" if consistent else "rejected"))
                    mean = statistics.mean(values)
                    target = case["initial_value"]*p["practical_target_fraction_V0"]
                    status, worst, best = practical(mean, q["lower"], q["upper"], target)
                    summary.append(dict(fixture=name, scenarios=n, config=config, confidence=alpha, seed_count=5,
                        mean_var=mean, sample_sd=statistics.stdev(values), reference=q["var"], reference_lower=q["lower"], reference_upper=q["upper"],
                        signed_error=mean-q["var"], absolute_error=abs(mean-q["var"]), practical_target=target,
                        worst_error=worst, best_error=best, practical=status, rejected_seeds=rejected,
                        consistency="not_rejected" if rejected == 0 else "rejected", endpoint=n == 10000000))
    write_rows("validation-details.csv", details)
    write_rows("convergence.csv", summary)
    raw = read_rows("benchmark-raw.csv")
    benchmark = []
    for name in p["benchmark"]["fixtures"]:
        for n in p["scenario_grid"]:
            groups = {config:[float(r["end_to_end_ms"]) for r in raw if r["fixture"] == name and int(r["scenarios"]) == n
                       and r["config"] == config and r["phase"] == "measured"] for config in p["benchmark"]["configurations"]}
            if any(len(v) != 10 for v in groups.values()): raise ValueError("Incomplete benchmark")
            means = {k:statistics.mean(v) for k, v in groups.items()}
            best = min((k for k in groups if k.startswith("openmp")), key=means.get)
            for config, values in groups.items():
                benchmark.append(dict(fixture=name, assets=len(fixture(ROOT/p["fixtures"][name]["path"])["assets"]), scenarios=n,
                    config=config, measured=10, excluded_warmups=3, mean_ms=means[config], sample_sd_ms=statistics.stdev(values),
                    scenarios_per_second=n*1000/means[config], serial_speedup=means["serial"]/means[config],
                    best_openmp=best, best_openmp_speedup=means[best]/means[config]))
    write_rows("benchmark-summary.csv", benchmark)
    print("Analysis complete", len(details), len(summary), len(benchmark))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("reference", "run", "analyze"))
    args = parser.parse_args()
    os.chdir(ROOT)
    {"reference": references, "run": run_campaign, "analyze": analyze}[args.action]()
