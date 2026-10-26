"""Published arithmetic checks and deliberate corruptions; standard library only."""
import contextlib
import copy
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('precision_verify',ROOT/'scripts/verify_portfolio_precision.py')
v=importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class PrecisionIntegrityTests(unittest.TestCase):
    def test_published_evidence(self):
        with contextlib.redirect_stdout(io.StringIO()):
            v.verify()

    def test_reject_changed_observations_and_decisions(self):
        original=v.rows
        for field,value in [('mean_var','0'),('old_status','fail'),('new_status','fail'),('lower','0')]:
            with self.subTest(field=field):
                def changed(path):
                    data=copy.deepcopy(original(path))
                    if path.name=='reassessment.csv':
                        data[0][field]=value
                    return data
                with patch.object(v,'rows',side_effect=changed),self.assertRaises(AssertionError):
                    v.verify()


if __name__=='__main__':
    unittest.main()
