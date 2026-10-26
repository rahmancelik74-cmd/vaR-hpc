"""Bounded PH-1 checks. No benchmark or historical data publication."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT/"evidence/portfolio-hybrid-20261026"
LOCAL = ROOT/"results/portfolio-hybrid-20261026"
BUILD = ROOT/"build-portfolio-hybrid-cuda"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    data=(json.dumps(value, indent=2, allow_nan=False)+"\n").encode("ascii")
    path=Path(path)
    if path.exists():
        if path.read_bytes()!=data: raise ValueError("Refusing to overwrite frozen evidence: "+str(path))
        return
    path.write_bytes(data)


def run(label, args, directory=PACKAGE, timeout=600):
    directory.mkdir(parents=True, exist_ok=True)
    target=directory/(label+".stdout.txt")
    if target.exists():
        process=json.loads((directory/(label+".process.json")).read_text())
        if process["command"]!=args or process["exit_code"]!=0 or process["stdout_sha256"]!=sha(target) or process["stderr_sha256"]!=sha(directory/(label+".stderr.txt")):
            raise ValueError("Existing evidence differs or failed; preserve and use a reviewed new attempt label: "+label)
        return target.read_bytes()  # Resume analysis without rerunning successful native samples.
    start=datetime.now(timezone.utc).isoformat()
    try:
        result=subprocess.run(args,cwd=ROOT,capture_output=True,timeout=timeout,
                              env=dict(os.environ,PYTHONUTF8="1",GIT_TERMINAL_PROMPT="0",GH_PROMPT_DISABLED="true"))
    except subprocess.TimeoutExpired as error:
        target.write_bytes(error.stdout or b"")
        (directory/(label+".stderr.txt")).write_bytes(error.stderr or b"")
        save(directory/(label+".process.json"),dict(command=args,started_utc=start,
             completed_utc=datetime.now(timezone.utc).isoformat(),exit_code=None,timed_out=True,
             stdout_sha256=sha(target),stderr_sha256=sha(directory/(label+".stderr.txt"))))
        raise
    target.write_bytes(result.stdout)
    (directory/(label+".stderr.txt")).write_bytes(result.stderr)
    save(directory/(label+".process.json"),dict(command=args,started_utc=start,
         completed_utc=datetime.now(timezone.utc).isoformat(),exit_code=result.returncode,
         stdout_sha256=sha(target),stderr_sha256=sha(directory/(label+".stderr.txt"))))
    if result.returncode:
        raise RuntimeError("Execution failed; inspect saved logs: "+label)
    return result.stdout


def freeze():
    frozen=json.loads((PACKAGE/"freeze.json").read_text())
    assert sha(PACKAGE/"PROTOCOL.md")==frozen["protocol_sha256"]
    for name,value in frozen["fixtures"].items():
        assert sha(ROOT/name)==value
    identities=PACKAGE/"identities.json"
    if identities.exists():
        for name,value in json.loads(identities.read_text())["sources"].items():
            if sha(ROOT/name)!=value: raise ValueError("Frozen execution source differs: "+name)


def statistical():
    import numpy as np
    from portfolio_campaign import fixture, terminal
    freeze()
    n=1000000
    bound=2*math.sqrt(math.log(2/.0025)/(2*n))+1/n
    checks=[]
    for index, name in enumerate(("two-positive","two-negative")):
        path=ROOT/("evidence/portfolio-campaign-20261025/fixtures/"+name+".txt")
        raw=run("native-"+name,[str(BUILD/"mc_var.exe"),"--portfolio",str(path),str(n),str(2026102601+index),
                "--backend","cuda","--cuda-mode","hybrid","--batch-size","65535","--json"])
        observed=json.loads(raw)
        f=fixture(path)
        reference=np.random.Generator(np.random.PCG64DXSM(2026102691+index)).standard_normal((n,2))
        losses=f["initial"]-terminal(f,reference)
        for estimate in observed["estimates"]:
            alpha=estimate["confidence"]
            cdf=float(np.count_nonzero(losses<=estimate["mc_var"])/n)
            checks.append(dict(fixture=name,confidence=alpha,native_var=estimate["mc_var"],reference_cdf=cdf,
                               error=abs(cdf-alpha),bound=bound,passed=abs(cdf-alpha)<=bound))
    save(PACKAGE/"statistical.json",dict(status="passed" if all(c["passed"] for c in checks) else "failed",
         scope="Bounded native distributional consistency only; no practical VaR target or universal acceptance",
         family_error=.01,uniform_DKW_events=4,n=n,numpy=np.__version__,checks=checks))
    assert all(c["passed"] for c in checks)


def historical():
    from verify_portfolio_calibration import audit
    folder=ROOT/"results/portfolio-historical-20261026-v4"
    LOCAL.mkdir(parents=True,exist_ok=True)
    report=audit(folder)  # Checks original input/metadata hashes and independent Decimal calibration.
    save(LOCAL/"historical-audit.json",report)
    raw=run("historical-hybrid",[str(BUILD/"mc_var.exe"),"--portfolio",str(folder/"portfolio.txt"),"10003","42",
        "--backend","cuda","--cuda-mode","hybrid","--batch-size","257","--cuda-diagnostics","--json"],LOCAL)
    observed=json.loads(raw)
    tokens=(folder/"portfolio.txt").read_text().split()
    p=observed["portfolio"]
    assert p["unit"]==tokens[1] and [a["id"] for a in p["assets"]]==[tokens[4],tokens[9]]
    assert observed["cuda"]["mode"]=="hybrid" and observed["cuda"]["asset_count"]==2
    assert observed["cuda"]["batch_count"]==39 and observed["scenarios"]==10003
    assert p["horizon_years"]==float(tokens[2])
    for i,asset in enumerate(p["assets"]):
        row=tokens[5+5*i:9+5*i]
        assert [asset[k] for k in ("quantity","initial_price","drift_annual","volatility_annual")]==list(map(float,row))
    assert all(e["analytical_var"] is None for e in observed["estimates"])
    save(LOCAL/"historical-result.json",dict(status="passed",portfolio_sha256=sha(folder/"portfolio.txt"),
        input_reused_unchanged=True,calibration_recomputed=False,private_only=True))
    save(PACKAGE/"historical-status.json",dict(status="passed",scope="Private existing calibration original-byte audit and modest hybrid integration; no predictive or statistical validation",private_outputs="results/portfolio-hybrid-20261026"))


def checks():
    vc=r'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
    for name,cuda,omp in (("cuda","ON","ON"),("serial","OFF","OFF"),("openmp","OFF","ON")):
        directory="build-portfolio-hybrid-"+name
        command='"'+vc+'" >nul && cmake -S . -B '+directory+' -G Ninja -DCMAKE_BUILD_TYPE=Release -DMC_ENABLE_CUDA='+cuda+' -DMC_ENABLE_OPENMP='+omp+' -DPython3_EXECUTABLE=C:/Users/rahma/anaconda3/python.exe'
        if cuda=="ON": command+=' -DCMAKE_CUDA_ARCHITECTURES=89'
        command+=' && cmake --build '+directory+' --parallel 4'
        LOCAL.mkdir(parents=True,exist_ok=True)
        batch=LOCAL/("build-"+name+".cmd")
        batch.write_bytes(("@echo off\r\ncall "+command+"\r\n").encode("ascii"))
        run("build-"+name+"-v2",["cmd","/d","/c",str(batch.relative_to(ROOT))])
        run("ctest-"+name,["ctest","--test-dir",directory,"--output-on-failure"])
    run("common-native-contract",[str(BUILD/"mc_portfolio_hybrid_tests.exe")])
    run("device-summary",["nvidia-smi","--query-gpu=name,driver_version,memory.total,memory.used,temperature.gpu,pstate,power.draw,power.limit,clocks.current.graphics,clocks.current.memory","--format=csv"])
    run("nvcc",["nvcc","--version"])
    sanitizer=r'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin\compute-sanitizer.bat'
    run("sanitizer-version",[sanitizer,"--version"])
    sanitizer=r'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\compute-sanitizer\compute-sanitizer.exe'
    for tool in ("memcheck","racecheck"):
        options=[sanitizer,"--tool",tool]
        if tool=="memcheck": options += ["--leak-check","full"]
        options += ["--error-exitcode","99"]
        # PH-1 full-matrix memcheck is archived separately; broad racecheck exceeded
        # 600 seconds. Focused coverage is an explicitly recorded supplement.
        run(tool+"-focused",options+[str(BUILD/"mc_portfolio_hybrid_tests.exe"),"--focused"],timeout=180)
    capacity=json.loads(run("capacity-five-10m",[str(BUILD/"mc_var.exe"),"--portfolio","data/portfolio-five.txt","10000000","42",
        "--backend","cuda","--cuda-mode","hybrid","--batch-size","65535","--cuda-diagnostics","--json"]))
    assert capacity["cuda"]["batch_count"]==153 and capacity["cuda"]["losses_transferred"]==10000000
    assert capacity["cuda"]["host_loss_bytes"]==80000000
    for backend,options in (("serial",[]),("cuda-full",["--cuda-mode","full-device"]),("cuda-hybrid",["--cuda-mode","hybrid","--batch-size","257"])):
        run("example-"+backend,[str(BUILD/"mc_var.exe"),"--portfolio","data/portfolio-two.txt","10003","42","--backend",
            "serial" if backend=="serial" else "cuda",*options,"--json"])


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase",choices=["checks","statistical","historical"])
    args=parser.parse_args()
    freeze()
    globals()[args.phase]()
    print(args.phase+" passed")
