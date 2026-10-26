"""Redistributable artificial prices only; tolerance fixed in the contract."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("calibration", ROOT/"scripts/calibrate_portfolio.py")
cal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cal)
audit_spec = importlib.util.spec_from_file_location("audit_calibration", ROOT/"scripts/verify_portfolio_calibration.py")
auditor = importlib.util.module_from_spec(audit_spec)
audit_spec.loader.exec_module(auditor)
TOL = 1e-12


def column(returns):
    values = [100.0]
    for r in returns:
        values.append(values[-1]*math.exp(r))
    return values


class CalibrationTests(unittest.TestCase):
    def near(self, actual, expected):
        self.assertLessEqual(abs(actual-expected), TOL*max(1,abs(expected)))

    def test_independent_known_statistics(self):
        # Centered x=(-1,1,-1,1)*.01, z=(1,1,-1,-1)*.01.
        # y=.01 + sign*.5*x + z. x.z=0; sums squares=.0004.
        for sign in (-1,0,1):
            x = [.01,.03,.01,.03]
            y = [.01+sign*.5*d+z for d,z in zip([-.01,.01,-.01,.01],[.01,.01,-.01,-.01])]
            s = cal.statistics([column(x),column(y)],252,10)
            self.assertEqual(s["returns_count"],4)
            for actual, expected in zip(s["mean_log_returns"],[.02,.01]):
                self.near(actual,expected)
            vx, vy, covariance = .0004/3, (.0004+sign*sign*.0001)/3, sign*.0002/3
            for actual, expected in zip(s["sample_covariance"][0],[vx,covariance]):
                self.near(actual,expected)
            self.near(s["sample_covariance"][1][1],vy)
            self.near(s["correlation"][0][1],sign/math.sqrt(5) if sign else 0)
            for i,(mean,var) in enumerate(((.02,vx),(.01,vy))):
                self.near(s["volatility_annual"][i],math.sqrt(var*252))
                self.near(s["drift_annual"][i],mean*252+.5*var*252)
            self.near(s["horizon_years"],10/252)

    def test_two_through_five_assets(self):
        for count in range(2,6):
            cols = [column([.01+.01*((t==i)-(t==5)) for t in range(6)]) for i in range(count)]
            s = cal.statistics(cols,252,10)
            self.assertEqual(len(s["correlation"]),count)
            self.near(s["correlation"][0][1],.5)

    def test_reject_statistics(self):
        good = column([.01,.03,.01,.03])
        for cols in ([good,[100]*5], [good,good],
                     [good,column([.01,.03+1e-10,.01,.03])],
                     [[1,2],[2,3]], [good,[1,2,3]], [good,[100,0,2,3,4]],
                     [good,[100,math.inf,2,3,4]], [good,[100,-1,2,3,4]]):
            with self.assertRaises(ValueError):
                cal.statistics(cols,252,10)
        for scale,horizon in ((0,10),(252,0),(math.inf,10)):
            with self.assertRaises((ValueError,OverflowError)):
                cal.statistics([good,column([.02,.02,0,0])],scale,horizon)
        with self.assertRaises(ValueError):
            cal.statistics([column([1,3,1,3]),column([2,2,0,0])],1e308,10)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.days = ["2024-01-02","2024-01-03","2024-01-04","2024-01-05","2024-01-08"]
        self.calendar = dict(coverage_start="2024-01-01",coverage_end="2024-12-31",
                             market="Nasdaq US cash equities",date_basis="America/New_York session date",
                             full_closures=["2024-01-01"],early_closes=[])
        (self.root/"calendar.json").write_text(json.dumps(self.calendar))
        self.request = dict(start="2024-01-01",end="2024-01-08",calendar="calendar.json",
                            frequency="daily",days_per_year=252,horizon_days=10,
                            assets=[dict(import_="B",quantity=1),dict(import_="A",quantity=1)])
        self.request["assets"] = [{"import": x["import_"],"quantity":1} for x in self.request["assets"]]
        for name, returns in (("A",[.01,.03,.01,.03]),("B",[.02,.02,0,0])):
            folder = self.root/name
            folder.mkdir()
            metadata = dict(source_name="Artificial fixture",source_url="https://example.invalid/fixture",
                            symbol=name,currency="USD",local_use_verified=True,data_kind="artificial_fixture",
                            price_adjustment_policy="unadjusted",close_definition="Synthetic Close",
                            price_policy_url="https://example.invalid/policy",reuse_policy_url="https://example.invalid/rights",
                            local_reuse_conditions="Original redistributable synthetic fixture",
                            currency_basis_url="https://example.invalid/currency",retrieved_utc="2024-01-09T00:00:00Z")
            (folder/"source-metadata.json").write_text(json.dumps(metadata))
            text = "date,close\n"+"".join(f"{d},{p:.17g}\n" for d,p in zip(self.days,column(returns)))
            (folder/"prices.csv").write_text(text)
            values = column(returns)
            raw = "".join("{},{:.17g},{:.17g},{:.17g},{:.17g},1\n".format(
                "/".join((d[5:7],d[8:10],d[:4])),p,p,p,p) for d,p in zip(self.days,values))
            (folder/"raw.csv").write_text(raw)
            manifest = dict(source=metadata,selected_price_field="close",invalid_rows_discarded=0,
                            observations_filled=0,source_format="kibot_daily",
                            requested_date_start="2024-01-01",requested_date_end="2024-01-08")
            self.write_manifest(name,manifest)
        self.save_request()

    def tearDown(self):
        self.temp.cleanup()

    def save_request(self):
        path = self.root/"request.json"
        path.write_text(json.dumps(self.request))
        return path

    def write_manifest(self,name,manifest=None):
        folder = self.root/name
        if manifest is None:
            manifest = json.loads((folder/"manifest.json").read_text())
        for file,key in (("raw.csv","raw_sha256"),("prices.csv","converted_sha256"),
                         ("source-metadata.json","source_metadata_sha256")):
            manifest[key] = hashlib.sha256((folder/file).read_bytes()).hexdigest()
        (folder/"manifest.json").write_text(json.dumps(manifest))

    def test_order_valuation_and_counts(self):
        first,text = cal.calibrate(self.save_request())
        self.request["assets"].reverse()
        second,reordered = cal.calibrate(self.save_request())
        self.assertEqual(text,reordered)
        self.assertEqual(first,second)
        self.assertEqual(first["asset_order"],["A","B"])
        self.assertEqual(first["data_kind"],"artificial_fixture")
        self.assertIn("not historical evidence",first["purpose"])
        self.assertEqual(first["valuation_date"],self.days[-1])
        self.assertEqual(first["observations_count"],5)
        self.assertEqual(first["returns_count"],4)

    def test_bad_dates_prices_and_sessions(self):
        path = self.root/"A/prices.csv"
        original = path.read_text()
        lines = original.splitlines(True)
        variants = [original+lines[-1],original.replace("2024-01-02","2024-02-30"),
                    "".join(lines[:2]+lines[3:]),original.replace("2024-01-02","2024-01-01"),
                    original.replace(",100\n",",nan\n"),original.replace(",100\n",",0\n"),
                    original+"\n",original.replace(",100\n",",1e400\n"),
                    original.replace("date,close","date,adjusted"),original.replace(",100\n",",bad\n"),
                    "".join(lines[:1]+list(reversed(lines[1:])))]
        for text in variants:
            path.write_text(text)
            self.write_manifest("A")
            with self.assertRaises(ValueError):
                cal.calibrate(self.save_request())

    def test_missing_from_all_assets(self):
        for name in ("A","B"):
            path = self.root/name/"prices.csv"
            lines = path.read_text().splitlines(True)
            path.write_text("".join(lines[:2]+lines[3:]))
            self.write_manifest(name)
        with self.assertRaisesRegex(ValueError,"sessions"):
            cal.calibrate(self.save_request())

    def test_metadata_mismatch(self):
        path = self.root/"B/source-metadata.json"
        original = json.loads(path.read_text())
        for key,value in (("currency","EUR"),("price_adjustment_policy","split_adjusted"),
                          ("close_definition","Different field"),("source_name","Other provider"),
                          ("local_use_verified",False),("symbol","A")):
            metadata = dict(original,**{key:value})
            path.write_text(json.dumps(metadata))
            manifest = json.loads((self.root/"B/manifest.json").read_text())
            manifest["source"] = metadata
            self.write_manifest("B",manifest)
            with self.assertRaises(ValueError):
                cal.calibrate(self.save_request())

    def test_hash_tampering(self):
        for file in ("raw.csv","source-metadata.json","prices.csv"):
            path = self.root/"A"/file
            original = path.read_bytes()
            path.write_bytes(original+b" ")
            with self.assertRaisesRegex(ValueError,"hash"):
                cal.calibrate(self.save_request())
            path.write_bytes(original)

    def test_calendar_rejection(self):
        for key,value in (("market","NYSE"),("coverage_end","2024-01-05"),
                          ("full_closures",["2024-01-01","2024-01-01"]),
                          ("full_closures",["2024-01-03"]),
                          ("early_closes",["2024-01-01"])):
            (self.root/"calendar.json").write_text(json.dumps(dict(self.calendar,**{key:value})))
            with self.assertRaises(ValueError):
                cal.calibrate(self.save_request())

    def test_explicit_window_exclusions(self):
        self.request.update(start="2024-01-03",end="2024-01-08")
        result,_ = cal.calibrate(self.save_request())
        self.assertEqual(result["assets"][0]["excluded_dates"],["2024-01-02"])
        self.assertEqual(result["returns_count"],3)

    def test_initial_value_overflow(self):
        self.request["assets"][0]["quantity"] = 1e308
        with self.assertRaisesRegex(ValueError,"overflow"):
            cal.calibrate(self.save_request())

    def test_cli_output_boundary_and_nonzero_failure(self):
        process = subprocess.run([sys.executable,str(ROOT/"scripts/calibrate_portfolio.py"),
                                  "--request",str(self.save_request()),"--output",str(self.root/"forbidden")],
                                 capture_output=True,text=True)
        self.assertNotEqual(process.returncode,0)
        self.assertFalse((self.root/"forbidden").exists())

    def test_cli_success_hashes_and_no_overwrite(self):
        results = ROOT/"results"
        results.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="test-portfolio-calibration-",dir=results) as temporary:
            output = Path(temporary)/"new"
            args = [sys.executable,str(ROOT/"scripts/calibrate_portfolio.py"),
                    "--request",str(self.save_request()),"--output",str(output)]
            process = subprocess.run(args,capture_output=True,text=True)
            self.assertEqual(process.returncode,0,process.stderr)
            self.assertEqual(auditor.audit(output)["status"],"passed")
            before = {p.name:p.read_bytes() for p in output.iterdir()}
            process = subprocess.run(args,capture_output=True,text=True)
            self.assertNotEqual(process.returncode,0)
            self.assertEqual(before,{p.name:p.read_bytes() for p in output.iterdir()})

    def audit_fixture(self):
        request_path = self.save_request()
        result,text = cal.calibrate(request_path)
        folder = self.root/"audit"
        folder.mkdir()
        (folder/"portfolio.txt").write_bytes(text.encode("ascii"))
        for source,target in ((request_path,"request.json"),(self.root/"calendar.json","calendar.json")):
            (folder/target).write_bytes(source.read_bytes())
        result.update(portfolio_sha256=cal.digest(folder/"portfolio.txt"),
                      request_sha256=cal.digest(request_path),calendar_sha256=cal.digest(self.root/"calendar.json"),
                      original_request_path=str(request_path))
        (folder/"calibration.json").write_text(json.dumps(result))
        return folder,result

    def test_independent_original_byte_audit(self):
        folder,_ = self.audit_fixture()
        result = auditor.audit(folder)
        self.assertEqual(result["status"],"passed")
        self.assertEqual(result["returns_count"],4)
        self.assertLess(max(result["max_absolute_differences"].values()),TOL)

    def test_independent_audit_detects_statistic_change(self):
        folder,data = self.audit_fixture()
        data["drift_annual"][0] += 1e-6
        (folder/"calibration.json").write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,"tolerance"):
            auditor.audit(folder)

    def test_independent_audit_detects_original_byte_change(self):
        folder,_ = self.audit_fixture()
        with (self.root/"A/raw.csv").open("ab") as handle:
            handle.write(b"\n")
        with self.assertRaisesRegex(ValueError,"hash"):
            auditor.audit(folder)

    def test_independent_audit_rejects_changed_valuation_date(self):
        folder,data = self.audit_fixture()
        data["valuation_date"] = "2024-01-05"
        (folder/"calibration.json").write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,"calendar"):
            auditor.audit(folder)


if __name__ == "__main__":
    unittest.main()
