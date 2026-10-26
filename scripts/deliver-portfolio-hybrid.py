"""Resume only the reviewed PH task on its actual ca6bb727 baseline.
No authentication/account/configuration/permission changes are performed.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
BASE="ca6bb72725115dc7f143cef3b5eda2649985d1c3"
REPO="rahmancelik74-cmd/vaR-hpc"
PACKAGE="evidence/portfolio-hybrid-20261026"
MANIFEST=PACKAGE+"/delivery-files.json"
STATE=ROOT/"results/portfolio-hybrid-delivery-20261026/state.json"
MESSAGE="Add explicit hybrid CUDA execution for portfolios"
# Filled once, after review; no globbing or implicit evidence staging at delivery.
FILES=[
    'CMakeLists.txt',
    'README.md',
    'docs/architecture.md',
    'docs/cuda-hybrid.md',
    'docs/portfolio-calibration.md',
    'docs/portfolio-hybrid.md',
    'docs/portfolio.md',
    'docs/project-state.md',
    'docs/reproducibility.md',
    'evidence/portfolio-hybrid-20261026/.gitattributes',
    'evidence/portfolio-hybrid-20261026/CMakeCache-cuda.txt',
    'evidence/portfolio-hybrid-20261026/CMakeCache-openmp.txt',
    'evidence/portfolio-hybrid-20261026/CMakeCache-serial.txt',
    'evidence/portfolio-hybrid-20261026/PROTOCOL.md',
    'evidence/portfolio-hybrid-20261026/README.md',
    'evidence/portfolio-hybrid-20261026/build-cuda-v2.process.json',
    'evidence/portfolio-hybrid-20261026/build-cuda-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/build-cuda-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/build-cuda.process.json',
    'evidence/portfolio-hybrid-20261026/build-cuda.stderr.txt',
    'evidence/portfolio-hybrid-20261026/build-cuda.stdout.txt',
    'evidence/portfolio-hybrid-20261026/build-openmp-v2.process.json',
    'evidence/portfolio-hybrid-20261026/build-openmp-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/build-openmp-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/build-serial-v2.process.json',
    'evidence/portfolio-hybrid-20261026/build-serial-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/build-serial-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/capacity-five-10m.process.json',
    'evidence/portfolio-hybrid-20261026/capacity-five-10m.stderr.txt',
    'evidence/portfolio-hybrid-20261026/capacity-five-10m.stdout.txt',
    'evidence/portfolio-hybrid-20261026/common-native-contract.process.json',
    'evidence/portfolio-hybrid-20261026/common-native-contract.stderr.txt',
    'evidence/portfolio-hybrid-20261026/common-native-contract.stdout.txt',
    'evidence/portfolio-hybrid-20261026/completion.json',
    'evidence/portfolio-hybrid-20261026/ctest-cuda.process.json',
    'evidence/portfolio-hybrid-20261026/ctest-cuda.stderr.txt',
    'evidence/portfolio-hybrid-20261026/ctest-cuda.stdout.txt',
    'evidence/portfolio-hybrid-20261026/ctest-openmp.process.json',
    'evidence/portfolio-hybrid-20261026/ctest-openmp.stderr.txt',
    'evidence/portfolio-hybrid-20261026/ctest-openmp.stdout.txt',
    'evidence/portfolio-hybrid-20261026/ctest-serial.process.json',
    'evidence/portfolio-hybrid-20261026/ctest-serial.stderr.txt',
    'evidence/portfolio-hybrid-20261026/ctest-serial.stdout.txt',
    'evidence/portfolio-hybrid-20261026/delivery-blockers.json',
    'evidence/portfolio-hybrid-20261026/delivery-files.json',
    'evidence/portfolio-hybrid-20261026/device-summary.process.json',
    'evidence/portfolio-hybrid-20261026/device-summary.stderr.txt',
    'evidence/portfolio-hybrid-20261026/device-summary.stdout.txt',
    'evidence/portfolio-hybrid-20261026/example-cuda-full.process.json',
    'evidence/portfolio-hybrid-20261026/example-cuda-full.stderr.txt',
    'evidence/portfolio-hybrid-20261026/example-cuda-full.stdout.txt',
    'evidence/portfolio-hybrid-20261026/example-cuda-hybrid.process.json',
    'evidence/portfolio-hybrid-20261026/example-cuda-hybrid.stderr.txt',
    'evidence/portfolio-hybrid-20261026/example-cuda-hybrid.stdout.txt',
    'evidence/portfolio-hybrid-20261026/example-serial.process.json',
    'evidence/portfolio-hybrid-20261026/example-serial.stderr.txt',
    'evidence/portfolio-hybrid-20261026/example-serial.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-build-cuda-v2.process.json',
    'evidence/portfolio-hybrid-20261026/final-build-cuda-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-build-cuda-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-build-cuda.process.json',
    'evidence/portfolio-hybrid-20261026/final-build-cuda.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-build-cuda.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-build-openmp.process.json',
    'evidence/portfolio-hybrid-20261026/final-build-openmp.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-build-openmp.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-build-serial.process.json',
    'evidence/portfolio-hybrid-20261026/final-build-serial.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-build-serial.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-contract-openmp.process.json',
    'evidence/portfolio-hybrid-20261026/final-contract-openmp.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-contract-openmp.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-contract-serial.process.json',
    'evidence/portfolio-hybrid-20261026/final-contract-serial.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-contract-serial.stdout.txt',
    'evidence/portfolio-hybrid-20261026/final-ctest-cuda.process.json',
    'evidence/portfolio-hybrid-20261026/final-ctest-cuda.stderr.txt',
    'evidence/portfolio-hybrid-20261026/final-ctest-cuda.stdout.txt',
    'evidence/portfolio-hybrid-20261026/freeze.json',
    'evidence/portfolio-hybrid-20261026/historical-status.json',
    'evidence/portfolio-hybrid-20261026/identities.json',
    'evidence/portfolio-hybrid-20261026/memcheck-focused.process.json',
    'evidence/portfolio-hybrid-20261026/memcheck-focused.stderr.txt',
    'evidence/portfolio-hybrid-20261026/memcheck-focused.stdout.txt',
    'evidence/portfolio-hybrid-20261026/memcheck.process.json',
    'evidence/portfolio-hybrid-20261026/memcheck.stderr.txt',
    'evidence/portfolio-hybrid-20261026/memcheck.stdout.txt',
    'evidence/portfolio-hybrid-20261026/native-two-negative.process.json',
    'evidence/portfolio-hybrid-20261026/native-two-negative.stderr.txt',
    'evidence/portfolio-hybrid-20261026/native-two-negative.stdout.txt',
    'evidence/portfolio-hybrid-20261026/native-two-positive.process.json',
    'evidence/portfolio-hybrid-20261026/native-two-positive.stderr.txt',
    'evidence/portfolio-hybrid-20261026/native-two-positive.stdout.txt',
    'evidence/portfolio-hybrid-20261026/nvcc.process.json',
    'evidence/portfolio-hybrid-20261026/nvcc.stderr.txt',
    'evidence/portfolio-hybrid-20261026/nvcc.stdout.txt',
    'evidence/portfolio-hybrid-20261026/prior-evidence-inventory.json',
    'evidence/portfolio-hybrid-20261026/python-regressions-v2.process.json',
    'evidence/portfolio-hybrid-20261026/python-regressions-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/python-regressions-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/python-regressions.stderr.txt',
    'evidence/portfolio-hybrid-20261026/python-regressions.stdout.txt',
    'evidence/portfolio-hybrid-20261026/racecheck-focused.process.json',
    'evidence/portfolio-hybrid-20261026/racecheck-focused.stderr.txt',
    'evidence/portfolio-hybrid-20261026/racecheck-focused.stdout.txt',
    'evidence/portfolio-hybrid-20261026/racecheck-matrix-timeout.json',
    'evidence/portfolio-hybrid-20261026/retained-integrity-v2.process.json',
    'evidence/portfolio-hybrid-20261026/retained-integrity-v2.stderr.txt',
    'evidence/portfolio-hybrid-20261026/retained-integrity-v2.stdout.txt',
    'evidence/portfolio-hybrid-20261026/retained-integrity.stdout.json',
    'evidence/portfolio-hybrid-20261026/sanitizer-binding.json',
    'evidence/portfolio-hybrid-20261026/sanitizer-original-test.cpp',
    'evidence/portfolio-hybrid-20261026/sanitizer-version.process.json',
    'evidence/portfolio-hybrid-20261026/sanitizer-version.stderr.txt',
    'evidence/portfolio-hybrid-20261026/sanitizer-version.stdout.txt',
    'evidence/portfolio-hybrid-20261026/statistical.json',
    'evidence/portfolio-hybrid-20261026/validation-summary.json',
    'include/mc/core.hpp',
    'scripts/.gitattributes',
    'scripts/check-portfolio-hybrid.py',
    'scripts/deliver-portfolio-hybrid.py',
    'src/cuda.cu',
    'src/output.cpp',
    'tests/test_cli.cmake',
    'tests/test_portfolio.cpp',
    'tests/test_portfolio_cli.cmake',
    'tests/test_portfolio_hybrid.cpp',
]


def require(ok,message):
    if not ok: raise ValueError(message)


def command(argv,timeout=60):
    result=subprocess.run(argv,cwd=ROOT,capture_output=True,encoding="utf-8",errors="strict",
        timeout=timeout,env=dict(os.environ,GIT_TERMINAL_PROMPT="0",GCM_INTERACTIVE="Never",
        GH_PROMPT_DISABLED="true",GIT_PAGER="cat",PAGER="cat",PYTHONUTF8="1"))
    if result.returncode: raise RuntimeError("Command failed: "+" ".join(argv)+"\n"+result.stderr.strip())
    return result.stdout.strip()


def git(*args): return command(["git","--no-pager",*args])
def gh(*args): return command(["gh",*args])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def persist(state):
    STATE.parent.mkdir(parents=True,exist_ok=True)
    state["updated_utc"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
    temporary=STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state,indent=2)+"\n",encoding="ascii")
    temporary.replace(STATE)


def reviewed_commit(sha):
    require(git("rev-parse",sha+"^")==BASE,"Unexpected parent; preserve newer work")
    require(git("log","-1","--format=%s",sha)==MESSAGE,"Unknown commit identity")
    require(set(git("diff-tree","--no-commit-id","--name-only","-r",sha).splitlines())==set(FILES),"Commit scope differs")
    for name in FILES:
        require(git("rev-parse",sha+":"+name)==git("hash-object","--path="+name,name),"Committed bytes differ: "+name)


def deliver(verify_only,seconds,state):
    require(60<=seconds<=1800,"CI wait must be 60..1800 seconds")
    require(Path(git("rev-parse","--show-toplevel")).resolve()==ROOT,"Wrong repository")
    require(git("branch","--show-current")=="main","Expected main branch")
    for flags in (("remote","get-url","--all","origin"),("remote","get-url","--push","--all","origin")):
        urls=git(*flags).splitlines()
        require(len(urls)==1 and urls[0] in ("https://github.com/"+REPO,"https://github.com/"+REPO+".git"),"Unauthorized destination")
    manifest=json.loads((ROOT/MANIFEST).read_text(encoding="ascii"))
    require(manifest["baseline"]==BASE and manifest["repository"]==REPO,"Manifest identity mismatch")
    require(len(FILES)==len(set(FILES)) and set(manifest["files"])==set(FILES)-{MANIFEST},"Explicit allowlist mismatch")
    for name,expected in manifest["files"].items():
        require(digest(ROOT/name)==expected,"Frozen exact-byte hash changed: "+name)
    # Git's CRLF conversion is allowed for ordinary sources, never frozen evidence.
    # Raw compiler/sanitizer logs may contain trailing spaces: preserve their bytes.
    review=[name for name in FILES if not name.startswith(PACKAGE+"/")]
    git("-c","core.whitespace=cr-at-eol","diff","--check","HEAD","--",*review)
    for name in review:
        require(all(line==line.rstrip(b" \t") for line in (ROOT/name).read_bytes().splitlines()),"Trailing whitespace: "+name)
    require(set(git("diff","--cached","--name-only").splitlines())<=set(FILES),"Unrelated staging exists; preserved")
    head=git("rev-parse","HEAD")
    if head!=BASE:
        reviewed_commit(head) # Recover an interrupted successful commit without rewriting it.
        require(not state.get("commit") or state["commit"]==head,"Saved HEAD differs")
        state["commit"]=head
    else: require(not state.get("commit"),"Saved commit is missing; stop without reset")
    require(not git("diff","--name-only","--","evidence",":(exclude)"+PACKAGE),"Prior evidence changed")
    if verify_only:
        print("PH baseline, explicit scope, exact bytes and CRLF-aware review passed; no Git write")
        return
    state.update(baseline=BASE,repository=REPO,status="reviewed")
    persist(state)
    require(gh("api","user","--jq",".login")=="rahmancelik74-cmd","Existing authentication is not the authorized account")
    remote=git("-c","http.sslBackend=openssl","ls-remote","origin","refs/heads/main").split()[0]
    require(remote in {BASE,state.get("commit")},"Remote advanced; preserve and review")
    if not state.get("commit"):
        git("add","--",*FILES)
        require(set(git("diff","--cached","--name-only").splitlines())==set(FILES),"Staged scope mismatch")
        for name in FILES:
            require(git("rev-parse",":"+name)==git("hash-object","--path="+name,name),"Staged object differs: "+name)
            if name.startswith(PACKAGE+"/"):
                require(git("rev-parse",":"+name)==git("hash-object","--no-filters",name),"Frozen evidence normalization rejected: "+name)
        git("-c","core.whitespace=cr-at-eol","diff","--cached","--check","--",*review)
        git("commit","-m",MESSAGE)
        state["commit"]=git("rev-parse","HEAD")
        persist(state)
    sha=state["commit"]
    reviewed_commit(sha)
    if remote!=sha: git("-c","http.sslBackend=openssl","push","origin","HEAD:refs/heads/main")
    require(git("-c","http.sslBackend=openssl","ls-remote","origin","refs/heads/main").split()[0]==sha,"Remote exact SHA differs")
    state.update(status="pushed",remote_sha=sha)
    persist(state)
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        runs=json.loads(gh("run","list","--repo",REPO,"--workflow","build.yml","--event","push","--commit",sha,
             "--limit","10","--json","databaseId,headSha,status,conclusion,url"))
        exact=[run for run in runs if run["headSha"]==sha]
        if exact:
            run=max(exact,key=lambda run:run["databaseId"])
            state.update(ci=run,status="ci_"+run["status"])
            persist(state)
            if run["status"]=="completed":
                require(run["conclusion"]=="success","Exact-SHA CI failed: "+run["url"])
                jobs=json.loads(gh("run","view",str(run["databaseId"]),"--repo",REPO,"--json","jobs"))["jobs"]
                require({j["name"] for j in jobs}=={"cpu (OFF)","cpu (ON)","windows-instrumentation"} and
                        all(j["conclusion"]=="success" for j in jobs),"CI jobs incomplete or unexpected")
                state.update(status="complete",ci_jobs=jobs,hosted_scope="CPU/synthetic checks only; local CUDA and private data not executed")
                persist(state)
                print(sha+" "+run["url"]+" success")
                return
        time.sleep(min(15,max(0,deadline-time.monotonic())))
    raise TimeoutError("Bounded CI wait expired; rerun to resume the saved exact SHA")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only",action="store_true")
    parser.add_argument("--ci-timeout",type=int,default=900)
    args=parser.parse_args()
    state={}
    try:
        if STATE.exists():
            state=json.loads(STATE.read_text(encoding="ascii"))
            require(state.get("baseline")==BASE and state.get("repository")==REPO,"Unrelated persistent state")
        deliver(args.verify_only,args.ci_timeout,state)
        return 0
    except (ValueError,RuntimeError,OSError,KeyError,subprocess.SubprocessError) as error:
        if not args.verify_only:
            state.update(baseline=BASE,repository=REPO,status="blocked",error=str(error))
            persist(state)
        print("PH delivery stopped: "+str(error),file=sys.stderr)
        return 1


if __name__=="__main__": sys.exit(main())
