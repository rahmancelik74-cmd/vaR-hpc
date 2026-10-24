"""Independent exact-moment oracle; rules are predeclared in docs/portfolio.md."""
import itertools
import json
import math
import subprocess
import sys

N = 200000
ASSERTIONS = 33  # Three cases, each: 3 means + 6 second moments + 2 VT moments.
ALPHA = 0.01


def raw_moment(order, rho):
    # Expand (sum_i VT_i)^order as ordered index tuples. No Cholesky or
    # production valuation code. Joint lognormal MGF gives each expectation.
    values = (200, 270, 320)
    drifts = (.03, .04, .05)
    sigmas = (.15, .18, .21)
    total = 0.0
    for indices in itertools.product(range(3), repeat=order):
        counts = [indices.count(i) for i in range(3)]
        weight = math.prod(values[i] ** counts[i] for i in range(3))
        exponent = sum(counts[i] * (drifts[i] - sigmas[i]**2 / 2) * .5
                       for i in range(3))
        exponent += .25 * sum(counts[i] * counts[j] * sigmas[i] * sigmas[j]
                              * (1 if i == j else rho)
                              for i in range(3) for j in range(3))
        total += weight * math.exp(exponent)
    return total


def main():
    result = subprocess.run([sys.argv[1], "--samples"], check=True,
                            text=True, capture_output=True)
    checks = []
    derived = []
    for line in result.stdout.splitlines():
        rho, *observed = map(float, line.split())
        expected = [0.] * 3
        variances = [1.] * 3
        for i in range(3):
            for j in range(i, 3):
                expected.append(1 if i == j else rho)
                variances.append(2 if i == j else 1 + rho*rho)
        m1, m2, m4 = (raw_moment(k, rho) for k in (1, 2, 4))
        expected += [m1, m2]
        variances += [m2-m1*m1, m4-m2*m2]
        for index, (value, mean, variance) in enumerate(zip(observed, expected, variances)):
            bound = math.sqrt(max(0, variance) * ASSERTIONS / (N * ALPHA))
            error = abs(value-mean)
            checks.append(dict(rho=rho, index=index, observed=value,
                               expected=mean, error=error, bound=bound))
            if error > bound:
                raise AssertionError(checks[-1])
        # Derived Pearson correlations and unbiased portfolio variance use the
        # same simultaneous 33 events, without additional confidence spending.
        bounds = [math.sqrt(v * ASSERTIONS / (N * ALPHA)) for v in variances]
        means = observed[:3]
        second = {(i, j): observed[k+3]
                  for k, (i, j) in enumerate(( (0,0),(0,1),(0,2),(1,1),(1,2),(2,2) ))}
        d = bounds[3] + bounds[0]**2
        pearson_bound = (math.sqrt((1+rho*rho)*ASSERTIONS/(N*ALPHA))
                         + bounds[0]**2 + abs(rho)*d)/(1-d)
        pearsons = []
        for i, j in ((0,1), (0,2), (1,2)):
            pearson = (second[i,j]-means[i]*means[j])/math.sqrt(
                (second[i,i]-means[i]**2)*(second[j,j]-means[j]**2))
            if abs(pearson-rho) > pearson_bound:
                raise AssertionError("Derived Pearson bound")
            pearsons.append(pearson)
        sample_variance = N/(N-1)*(observed[10]-observed[9]**2)
        model_variance = m2-m1*m1
        variance_bound = N/(N-1)*(bounds[10]+2*abs(m1)*bounds[9]+bounds[9]**2) + model_variance/(N-1)
        if abs(sample_variance-model_variance) > variance_bound:
            raise AssertionError("Derived variance bound")
        derived.append(dict(rho=rho, pearson_correlations=pearsons,
                            pearson_absolute_bound=pearson_bound,
                            sample_terminal_variance=sample_variance,
                            expected_terminal_variance=model_variance,
                            variance_absolute_bound=variance_bound))
    if len(checks) != ASSERTIONS:
        raise AssertionError("Incomplete independent moment coverage")
    print(json.dumps(dict(status="passed", seed=20261025, scenarios=N,
                          family_alpha=ALPHA, rule="Chebyshev/Bonferroni",
                          scope="test RNG production transform and valuation; not native backend RNG moments",
                          checks=checks, derived=derived), indent=2))


if __name__ == "__main__":
    main()
