"""Offline provenance tests; no Matplotlib, raw GPU archive or engine needed."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "evidence/v030-convergence-figures-20261020-v2/convergence_figures.py"
SPEC = importlib.util.spec_from_file_location("convergence_figures_v2", SCRIPT)
FIGURES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIGURES)


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="convergence-provenance-test-")
        self.root = Path(self.temp.name).resolve()
        self.assertEqual(self.root.parent, Path(tempfile.gettempdir()).resolve())
        self.source = self.root / "evidence"
        self.policy_path = self.root / "package/provenance-policy.json"
        self.source.mkdir()
        (self.root / "docs").mkdir()
        documents = {}
        for name in ("project-state.md", "convergence.md"):
            relative = "docs/" + name
            path = self.root / relative
            path.write_bytes(b"Historical documentation.\n")
            snapshot = "historical-documents/" + relative
            target = self.policy_path.parent / snapshot
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
            documents[relative] = snapshot
        shutil.copyfile(REPOSITORY / "evidence/v030-convergence-windows-20261020/per-seed.csv",
                        self.source / "per-seed.csv")
        (self.root / "raw.stdout.txt").write_bytes(b"Bound raw artifact.\n")
        manifest = {"actual_repository_root": str(self.root), "artifacts": [
            {"path": name, "sha256": FIGURES.sha(self.root / name)}
            for name in (*documents, "evidence/per-seed.csv", "raw.stdout.txt")]}
        manifest_path = self.source / "delivery-manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="ascii")
        self.git("init", "-q")
        self.git("-c", "core.autocrlf=false", "add", "docs", "evidence", "raw.stdout.txt")
        self.git("-c", "user.name=Convergence Test", "-c", "user.email=test@example.invalid",
                 "commit", "-qm", "Historical snapshot")
        revision = self.git("rev-parse", "HEAD").decode("ascii").strip()
        self.policy = {"schema_version": 2, "snapshot_revision": revision,
                       "parent_manifest_sha256": FIGURES.sha(manifest_path),
                       "parent_manifest_repository_path": "evidence/delivery-manifest.json",
                       "historical_documents": documents}
        self.save_policy()

    def tearDown(self):
        self.assertEqual(self.root.parent, Path(tempfile.gettempdir()).resolve())
        # Git can mark objects read-only on Windows; let TemporaryDirectory handle them.
        self.temp.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.root), *arguments],
                                       stderr=subprocess.PIPE)

    def save_policy(self):
        self.policy_path.write_text(json.dumps(self.policy), encoding="ascii")

    def verify(self):
        return FIGURES.verify_delivery_manifest(self.source, self.root, self.policy_path)

    def test_historical_snapshot_and_current_artifacts(self):
        _, result = self.verify()
        self.assertEqual(len(result["historical_documents"]), 2)
        self.assertEqual(len(result["current_artifacts"]), 2)

    def test_later_documentation_change_is_not_numerical_corruption(self):
        (self.root / "docs/project-state.md").write_bytes(b"Legitimate later update.\n")
        (self.root / "docs/convergence.md").write_bytes(b"Current figures are documented here.\n")
        self.verify()

    def test_real_numerical_csv_change_still_fails(self):
        path = self.source / "per-seed.csv"
        data = path.read_bytes()
        path.write_bytes(data.replace(b"6.037987452540781", b"7.037987452540781", 1))
        self.assertNotEqual(path.read_bytes(), data, "Test must change a real numeric value")
        with self.assertRaisesRegex(ValueError, "delivery hash evidence/per-seed.csv"):
            self.verify()

    def test_historical_raw_snapshot_change_fails(self):
        path = self.policy_path.parent / self.policy["historical_documents"]["docs/project-state.md"]
        path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        with self.assertRaisesRegex(ValueError, "historical raw bytes"):
            self.verify()

    def test_manifest_tampering_fails(self):
        path = self.source / "delivery-manifest.json"
        path.write_bytes(path.read_bytes() + b" ")
        with self.assertRaisesRegex(ValueError, "parent manifest bytes"):
            self.verify()

    def test_missing_raw_dependency_fails(self):
        (self.root / "raw.stdout.txt").unlink()
        with self.assertRaises(FileNotFoundError):
            self.verify()

    def test_document_role_cannot_exempt_numerical_data(self):
        self.policy["historical_documents"]["evidence/per-seed.csv"] = "unused"
        self.save_policy()
        with self.assertRaisesRegex(ValueError, "historical roles"):
            self.verify()

    def test_git_snapshot_content_is_checked_separately(self):
        (self.root / "docs/project-state.md").write_bytes(b"A different historical document.\n")
        self.git("add", "docs/project-state.md")
        self.git("-c", "user.name=Convergence Test", "-c", "user.email=test@example.invalid",
                 "commit", "-qm", "Later snapshot")
        self.policy["snapshot_revision"] = self.git("rev-parse", "HEAD").decode().strip()
        self.save_policy()
        with self.assertRaisesRegex(ValueError, "historical Git content"):
            self.verify()

    def test_relocation_and_traversal(self):
        self.assertEqual(FIGURES.resolve_recorded_path(self.root, "C:/old/repo/raw.txt", "C:/old/repo"),
                         self.root / "raw.txt")
        with self.assertRaises(ValueError):
            FIGURES.resolve_recorded_path(self.root, "C:/old/repo/../outside", "C:/old/repo")
        with self.assertRaises(ValueError):
            FIGURES.resolve_recorded_path(self.root, "C:/unrelated/file", "C:/old/repo")

    def test_near_zero_and_negative_reference_normalization(self):
        FIGURES.verify_normalization({"error_over_v0": "0.02", "relative_error": "N/A",
                                      "relative_status": "N/A: near-zero reference"}, 0, 100, 2)
        FIGURES.verify_normalization({"error_over_v0": "-0.02", "relative_error": "0.2",
                                      "relative_status": "available"}, -10, 100, -2)
        with self.assertRaises(ValueError):
            FIGURES.verify_normalization({"error_over_v0": "0.02", "relative_error": "0",
                                          "relative_status": "N/A: near-zero reference"}, 0, 100, 2)

    def test_log_zero_is_marked_without_changing_raw_values(self):
        raw = [1.0, 0.0, 10.0]
        displayed, zero_x = FIGURES.positive_log_points([10_000, 100_000, 1_000_000], raw)
        self.assertEqual(raw, [1.0, 0.0, 10.0])
        self.assertEqual(zero_x, [100_000])
        self.assertTrue(math.isnan(displayed[1]))
        self.assertEqual((displayed[0], displayed[2]), (1.0, 10.0))
        for bad in ([-1.0], [math.nan], [math.inf]):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                FIGURES.positive_log_points([10_000], bad)


if __name__ == "__main__":
    unittest.main()
