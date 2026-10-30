"""Run controller regressions when Node is available; no browser emulation claim."""
from pathlib import Path
import shutil
import subprocess
import unittest


class LocalUIControllerTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node is required for controller regressions')
    def test_controller_lifecycle(self):
        subprocess.run([shutil.which('node'), '--test', str(Path(__file__).with_suffix('.cjs'))],
                       check=True, timeout=30)
