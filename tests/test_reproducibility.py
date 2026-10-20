"""Focused failure handling for the read-only reproducibility entry point."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest

SPEC = importlib.util.spec_from_file_location("repro", Path(__file__).resolve().parents[1] / "scripts/check-reproducibility.py")
REPRO = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPRO)


class ReproducibilityTests(unittest.TestCase):
    def test_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "escapes"):
                REPRO.checked_child(Path(directory), "../outside")

    def test_missing_local_archive_is_actionable(self):
        def missing(*args):
            raise FileNotFoundError("original-runtime.stdout.txt")
        with self.assertRaisesRegex(ValueError, "Restore the exact hash-bound"):
            REPRO.local_convergence(Path("."), types.SimpleNamespace(validate=missing))

    def test_local_corruption_is_not_reported_as_missing(self):
        def corrupt(*args):
            raise ValueError("Changed numerical input")
        with self.assertRaisesRegex(ValueError, "Changed numerical input"):
            REPRO.local_convergence(Path("."), types.SimpleNamespace(validate=corrupt))

    def test_changed_real_csv_fails_even_without_local_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "package").mkdir()
            csv = root / "package/values.csv"
            csv.write_bytes(b"value\n1.25\n")
            inventory = json.dumps([{"file": "values.csv", "sha256": hashlib.sha256(csv.read_bytes()).hexdigest()}]).encode()
            (root / "package/manifest.json").write_bytes(inventory)
            def equal(actual, expected, label):
                if actual != expected:
                    raise ValueError(label)
            helper = types.SimpleNamespace(git_bytes=lambda *args: inventory,
                read_json=lambda p: json.loads(p.read_bytes()), check_equal=equal,
                sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertEqual(REPRO.check_inventory(root, "package", "manifest.json", helper), 1)
            csv.write_bytes(b"value\n9.25\n")
            with self.assertRaisesRegex(ValueError, "Selected artifact"):
                REPRO.check_inventory(root, "package", "manifest.json", helper)
            (root / "package/manifest.json").write_bytes(b"[]")
            with self.assertRaisesRegex(ValueError, "Historical inventory"):
                REPRO.check_inventory(root, "package", "manifest.json", helper)


if __name__ == "__main__":
    unittest.main()
