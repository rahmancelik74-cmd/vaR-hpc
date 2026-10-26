"""Focused follow-up checks; never generate large reference samples."""
import importlib.util
import math
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('precision',ROOT/'scripts/portfolio_precision.py')
p=importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class PrecisionTests(unittest.TestCase):
    def test_classification(self):
        self.assertEqual(p.classify(10,9.9,10.1,.5),'pass')
        self.assertEqual(p.classify(10.45,9.9,10.1,.5),'inconclusive')
        self.assertEqual(p.classify(11,9.9,10.1,.5),'fail')
        self.assertEqual(p.classify(10,9,11,.5),'inconclusive')

    def setUp(self):
        try:
            import numpy
            import scipy
        except ImportError:
            if self._testMethodName!='test_classification':
                self.skipTest('Optional local NumPy/SciPy not installed')

    def test_rank_coverage(self):
        for n in (10000,80000000):
            for a in (.95,.99):
                lo,hi,c=p.rank_interval(n,a,.0025)
                self.assertTrue(0<=lo<hi<n)
                self.assertGreaterEqual(c, .9975-1e-12)
        with self.assertRaises(ArithmeticError):
            p.rank_interval(100,.99,.0025)

    def test_valuation_reductions_and_small_scenarios(self):
        import numpy as np
        f=p.fixture(p.OLD/'fixtures/two-positive.txt')
        eps=np.array([[0.,0.],[1.,0.],[-1.,2.],[0.,1.]])
        expected=[]
        for x,y in eps:
            expected.append(200*math.exp(.03+.2*x)+240*math.exp(-.015+.3*(.6*x+.8*y)))
        self.assertLess(float(max(abs(p.terminal(f,eps)-expected))),1e-10)
        self.assertEqual(float(np.quantile(f['initial']-p.terminal(f,eps),.95,method='inverted_cdf')),max(f['initial']-p.terminal(f,eps)))
        f['horizon']=0
        np.testing.assert_array_equal(p.terminal(f,eps),[440]*4)
        f['horizon']=1
        f['assets'][0][3]=f['assets'][1][3]=0
        self.assertLess(abs(p.terminal(f,eps)[0]-(200*math.exp(.05)+240*math.exp(.03))),1e-10)
        self.assertLess(f['initial']-p.terminal(f,eps)[0],0)

    def test_known_cdf_reductions(self):
        from scipy.special import ndtri
        f=dict(assets=[[1,100,.05,.2],[1,50,.03,0]],rho=.6,horizon=1,initial=150)
        for alpha in (.95,.99):
            expected=150-(100*math.exp(.03+.2*float(ndtri(1-alpha)))+50*math.exp(.03))
            self.assertAlmostEqual(p.numerical_quantile(f,alpha)['var'],expected,places=8)
        f['horizon']=0
        self.assertEqual(p.cdf(f,149)[0],0)
        self.assertEqual(p.cdf(f,151)[0],1)

    def test_exact_moments(self):
        import numpy as np
        f=p.fixture(p.OLD/'fixtures/two-negative.txt')
        rng=np.random.Generator(np.random.PCG64DXSM(1749202699))
        vt=p.terminal(f,rng.standard_normal((100000,2)))
        m1,m2,m4=[p.moments(f,k) for k in (1,2,4)]
        self.assertLess(abs(float(vt.mean())-m1),8*math.sqrt((m2-m1*m1)/len(vt)))
        self.assertLess(abs(float(np.mean(vt*vt))-m2),8*math.sqrt((m4-m2*m2)/len(vt)))

    def test_swap_tight_transform(self):
        f=p.fixture(p.OLD/'fixtures/two-negative.txt')
        q=p.numerical_quantile(f,.99)['var']
        for mode in ('tight','probability'):
            self.assertLess(abs(q-p.numerical_quantile(f,.99,mode)['var']),1e-7)
        self.assertLess(abs(q-p.numerical_quantile(dict(f,assets=list(reversed(f['assets']))),.99)['var']),1e-7)


if __name__=='__main__':
    unittest.main()
