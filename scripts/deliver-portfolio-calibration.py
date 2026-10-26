"""Narrow normal Git delivery for the reviewed historical calibration task.

No credential, global configuration, permission or visibility changes.
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

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "c21efc1258898aabe26d065de7c50961b79e94e0"
REPO = "rahmancelik74-cmd/vaR-hpc"
PACKAGE = "evidence/portfolio-calibration-20261026"
MANIFEST = PACKAGE+"/delivery-files.json"
TASK_FILES = ["CMakeLists.txt","docs/architecture.md","docs/historical-data.md",
              "docs/portfolio.md","docs/portfolio-calibration.md","docs/project-state.md",
              "docs/reproducibility.md","scripts/.gitattributes",
              "scripts/calibrate_portfolio.py","scripts/verify_portfolio_calibration.py",
              "scripts/deliver-portfolio-calibration.py","tests/test_portfolio_calibration.py",
              PACKAGE+"/.gitattributes",PACKAGE+"/README.md",PACKAGE+"/completion.json",MANIFEST]
STATE = ROOT/"results/portfolio-calibration-delivery-20261026/state.json"


def check(condition, message):
    if not condition:
        raise ValueError(message)


def run(args, timeout=90):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never",
               GH_PROMPT_DISABLED="true",GIT_PAGER="cat",PAGER="cat",PYTHONUTF8="1")
    process = subprocess.run(args,cwd=ROOT,env=env,capture_output=True,
                             encoding="utf-8",errors="strict",timeout=timeout)
    if process.returncode:
        raise RuntimeError(f"Command failed ({process.returncode}): {' '.join(args)}\n{process.stderr.strip()}")
    return process.stdout.strip()


def git(*args):
    return run(["git","--no-pager",*args])


def gh(*args):
    return run(["gh",*args])


def save(state):
    STATE.parent.mkdir(parents=True,exist_ok=True)
    state["updated_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state,indent=2)+"\n",encoding="ascii")
    temporary.replace(STATE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only",action="store_true")
    parser.add_argument("--ci-timeout",type=int,default=1200)
    args = parser.parse_args()
    state = {}
    try:
        check(60 <= args.ci_timeout <= 1800,"CI deadline must be 60..1800 seconds")
        check(Path(git("rev-parse","--show-toplevel")).resolve() == ROOT,"Wrong repository root")
        check(git("branch","--show-current") == "main","Expected main")
        urls = {"https://github.com/"+REPO,"https://github.com/"+REPO+".git"}
        for options in (("remote","get-url","--all","origin"),("remote","get-url","--push","--all","origin")):
            configured = git(*options).splitlines()
            check(len(configured) == 1 and configured[0] in urls,"Unauthorized or ambiguous remote")
        manifest = json.loads((ROOT/MANIFEST).read_text())
        check(manifest["baseline"] == BASELINE,"Manifest baseline mismatch")
        check(set(manifest["files"]) == set(TASK_FILES)-{MANIFEST},"Manifest scope mismatch")
        for name, expected in manifest["files"].items():
            check(hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected,
                  "Exact local-byte task-file hash mismatch: " + name)
        if STATE.exists():
            state = json.loads(STATE.read_text())
            check(state.get("baseline") == BASELINE and state.get("repository") == REPO,"Unrelated delivery state")
        head = git("rev-parse","HEAD")
        if state.get("commit"):
            check(head == state["commit"],"HEAD advanced since saved commit; preserve newer work and review")
            check(git("rev-parse",head+"^") == BASELINE,"Saved commit parent mismatch")
            check(set(git("diff-tree","--no-commit-id","--name-only","-r",head).splitlines()) == set(TASK_FILES),
                  "Saved commit scope mismatch")
        elif head != BASELINE:
            # Recover a commit that succeeded immediately before state persistence failed.
            check(git("rev-parse",head+"^") == BASELINE,"HEAD changed; do not reset or reuse an obsolete guard")
            check(git("log","-1","--format=%s") == "Add strict historical portfolio calibration", "Unknown new commit")
            check(set(git("diff-tree","--no-commit-id","--name-only","-r",head).splitlines()) == set(TASK_FILES),
                  "Cannot recover commit with different scope")
            for name in TASK_FILES:
                check(git("rev-parse",head+":"+name) == git("hash-object","--path="+name,name),
                      "Recovered commit differs from reviewed bytes: "+name)
            state.update(commit=head,status="commit_recovered")
        staged = set(git("diff","--cached","--name-only").splitlines())
        check(staged <= set(TASK_FILES),"Unrelated staging; preserved without alteration")
        run(["git","-c","core.whitespace=cr-at-eol","diff","--check","HEAD","--",*TASK_FILES])
        for name in TASK_FILES:
            data = (ROOT/name).read_bytes()
            check(all(line == line.rstrip(b" \t") for line in data.splitlines()),"Trailing whitespace: "+name)
        run([sys.executable,"-B","-m","unittest","discover","-s","tests","-p","test_portfolio_calibration.py","-v"])
        if args.verify_only:
            print("Reviewed task hashes, scope and synthetic checks passed; no Git write or credential query")
            return 0
        state.update(baseline=BASELINE,repository=REPO,status="preflight_passed")
        save(state)
        check(gh("api","user","--jq",".login") == "rahmancelik74-cmd","Wrong GitHub account")
        remote = git("-c","http.sslBackend=openssl","ls-remote","origin","refs/heads/main").split()[0]
        check(remote in {BASELINE,state.get("commit")},"Remote main advanced; preserve newer work and review")
        if not state.get("commit"):
            git("add","--",*TASK_FILES)
            check(set(git("diff","--cached","--name-only").splitlines()) == set(TASK_FILES),"Unexpected staged scope")
            for name in TASK_FILES:
                check(git("rev-parse",":"+name) == git("hash-object","--path="+name,name),
                      "Staged normalization differs from reviewed local bytes: "+name)
            git("commit","-m","Add strict historical portfolio calibration")
            state.update(commit=git("rev-parse","HEAD"),status="committed")
            save(state)
        commit = state["commit"]
        check(not git("diff","HEAD","--name-only","--",*TASK_FILES),"Task files changed after commit")
        if remote != commit:
            git("-c","http.sslBackend=openssl","push","origin","HEAD:refs/heads/main")
        check(git("-c","http.sslBackend=openssl","ls-remote","origin","refs/heads/main").split()[0] == commit,
              "Remote exact SHA mismatch")
        state.update(status="pushed",remote_sha=commit)
        save(state)
        deadline = time.monotonic()+args.ci_timeout
        while time.monotonic() < deadline:
            runs = json.loads(gh("run","list","--repo",REPO,"--commit",commit,"--workflow","build.yml",
                                 "--event","push","--limit","10","--json",
                                 "databaseId,headSha,status,conclusion,url,workflowName"))
            exact = [r for r in runs if r["headSha"] == commit]
            if exact:
                latest = max(exact,key=lambda r:r["databaseId"])
                state.update(ci=latest,status="ci_"+latest["status"])
                save(state)
                if latest["status"] == "completed":
                    check(latest["conclusion"] == "success","Exact-SHA CI did not succeed: "+latest["url"])
                    jobs = json.loads(gh("run","view",str(latest["databaseId"]),"--repo",REPO,"--json","jobs"))["jobs"]
                    check({j["name"] for j in jobs} == {"cpu (OFF)","cpu (ON)","windows-instrumentation"}
                          and all(j["conclusion"] == "success" for j in jobs),"Unexpected or unsuccessful CI jobs")
                    state.update(status="complete",ci_jobs=jobs)
                    save(state)
                    print("Normal commit/push and exact-SHA CI passed: "+commit+" "+latest["url"])
                    return 0
            time.sleep(min(15,max(0,deadline-time.monotonic())))
        raise TimeoutError("Bounded exact-SHA CI wait expired; rerun to resume saved commit")
    except (ValueError,RuntimeError,OSError,KeyError,subprocess.SubprocessError) as exc:
        if not args.verify_only:
            state.update(baseline=BASELINE,repository=REPO,status="blocked",error=str(exc))
            save(state)
        print("Delivery stopped: "+str(exc),file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
