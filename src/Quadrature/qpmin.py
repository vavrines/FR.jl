import json
import numpy
import pathlib
import warnings
from sympy import Rational as frac

this_dir = pathlib.Path(__file__).resolve().parent


def williams_shunn_jameson_1():
    d = {"centroid": [[1]]}
    return T2Scheme("Williams-Shunn-Jameson 1", d, 1)


def williams_shunn_jameson_2():
    d = {"d3_aa": [[frac(1, 3)], [frac(1, 6)]]}
    return T2Scheme("Williams-Shunn-Jameson 2", d, 2)


def williams_shunn_jameson_3():
    return _read(this_dir / "williams_shunn_jameson_3.json")


def williams_shunn_jameson_4():
    return _read(this_dir / "williams_shunn_jameson_4.json")


def williams_shunn_jameson_5():
    return _read(this_dir / "williams_shunn_jameson_5.json")


def williams_shunn_jameson_6():
    return _read(this_dir / "williams_shunn_jameson_6.json")


def williams_shunn_jameson_7():
    return _read(this_dir / "williams_shunn_jameson_7.json")


def williams_shunn_jameson_8():
    return _read(this_dir / "williams_shunn_jameson_8.json")


def _read(filepath, source=None):
    with open(filepath) as f:
        content = json.load(f)

    degree = content["degree"]
    name = content["name"]
    tol = content["test_tolerance"]
    d = content["data"]
    weight_factor = content["weight factor"] if "weight factor" in content else None
    return T2Scheme(name, d, degree, source, tol, weight_factor=weight_factor)


class QuadratureScheme:
    def __init__(
        self, name, weights, points, degree, source, tol=1.0e-14, comments=None
    ):
        if tol > 1.0e-12:
            warnings.warn(
                f"{name} ({self.domain}) has low precision ({tol:.3e}).")

        self.test_tolerance = tol
        self.name = name
        self.degree = degree
        self.source = source
        self.comments = [] if comments is None else comments

        if weights.dtype == numpy.float64:
            self.weights = weights
        else:
            assert weights.dtype in [numpy.dtype("O"), numpy.int_]
            self.weights = weights.astype(numpy.float64)
            self.weights_symbolic = weights

        if points.dtype == numpy.float64:
            self.points = points
        else:
            assert points.dtype in [numpy.dtype("O"), numpy.int_]
            self.points = points.astype(numpy.float64)
            self.points_symbolic = points


class TnScheme(QuadratureScheme):
    def __init__(
        self, name, dim, weights, points, degree, source, tol=1.0e-14, comments=None
    ):
        self.domain = f"Tn (n={dim})"
        self.dim = dim
        super().__init__(name, weights, points, degree, source, tol, comments)


class T2Scheme(TnScheme):
    def __init__(
        self,
        name,
        symmetry_data,
        degree,
        source=None,
        tol=1.0e-14,
        comments=None,
        weight_factor=None,
    ):
        self.symmetry_data = symmetry_data

        points, weights = expand_symmetries(symmetry_data, dim=2)
        if weight_factor is not None:
            weights *= weight_factor

        assert points.shape[0] == 3, f"{name}, {points.shape}"
        super().__init__(name, 2, weights, points, degree, source, tol, comments)
        self.domain = "T2"


def expand_symmetries_points_only(data, dim):
    points = []
    counts = []

    for key, points_raw in data.items():
        fun = {
            "zero2": _zero,
            "zero3": _zero,
            "0": _zero,
            #
            "a": _a,
            "a0": _a0,
            #
            "d4_aa": _d4_aa,
            "d4_a0": _d4_a0,
            "c4": _c4,
            "d4_ab": _d4_ab,
            "c2_a0": _c2_a0,
            "c2_0a": _c2_0a,
            "sxy": _sxy,
            "c2": _c2,
            "sx": _sx,
            #
            "centroid": _centroid,
            "vertex": _vertex,
            "d3_ab": _d3_ab,
            "d3_aa": _d3_aa,
            "c3_ab": _c3_ab,
            "swap_ab": _swap_ab,
            "s2_static": _s2_static,
            #
            "d4.0": lambda r, dim: _d(4, 0, r),
            "d4.1": lambda r, dim: _d(4, 1, r),
            "d5.0": lambda r, dim: _d(5, 0, r),
            "d6.0": lambda r, dim: _d(6, 0, r),
            "d6.1": lambda r, dim: _d(6, 1, r),
            "d8.0": lambda r, dim: _d(8, 0, r),
            "d8.1": lambda r, dim: _d(8, 1, r),
            "d10.0": lambda r, dim: _d(10, 0, r),
            "d10.1": lambda r, dim: _d(10, 1, r),
            #
            "symm_r00": _symm_r00,
            "symm_rr0": _symm_rr0,
            "symm_rs0_roll": _symm_rs0_roll,
            "symm_rrr": _symm_rrr,
            "symm_rrs": _symm_rrs,
            "symm_rss_pm": _symm_rss_pm,
            #
            "plain": lambda vals, dim: vals.reshape(vals.shape[0], 1, -1),
        }[key]
        pts = fun(numpy.asarray(points_raw), dim)

        counts.append(pts.shape[1])
        pts = pts.reshape(pts.shape[0], -1)
        points.append(pts)

    points = numpy.ascontiguousarray(numpy.concatenate(points, axis=1))
    return points, counts


def expand_symmetries(data, dim):
    # separate points and weights
    points_raw = {}
    weights_raw = []
    for key, values in data.items():
        weights_raw.append(values[0])
        points_raw[key] = values[1:]

    points, counts = expand_symmetries_points_only(points_raw, dim)
    weights = numpy.concatenate(
        [numpy.tile(values, count)
         for count, values in zip(counts, weights_raw)]
    )
    return points, weights


def _zero(data, dim):
    return numpy.zeros((dim, 1))


def _d4_ab(data, dim):
    """dihedral symmetry d4."""
    s, t = numpy.array(data)
    points = numpy.array(
        [[+s, +t], [-s, +t], [+s, -t], [-s, -t],
            [+t, +s], [-t, +s], [+t, -s], [-t, -s]]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _d4_aa(data, dim):
    a = numpy.asarray(data)
    points = numpy.array([[+a, +a], [-a, +a], [+a, -a], [-a, -a]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _d4_a0(data, dim):
    a = numpy.asarray(data)
    zero = numpy.zeros_like(a)
    points = numpy.array([[+a, zero], [-a, zero], [zero, +a], [zero, -a]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _c4(data, dim):
    a, b = data
    points = numpy.array([[+a, +b], [-a, -b], [-b, +a], [+b, -a]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _sxy(data, dim):
    x, y = data
    points = numpy.array([[+x, +y], [+x, -y], [-x, +y], [-x, -y]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _sx(data, dim):
    x, y = data
    points = numpy.array([[+x, y], [-x, y]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _c2(data, dim):
    x, y = data
    points = numpy.array([[+x, +y], [-x, -y]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _c2_a0(r, dim):
    zero = numpy.zeros_like(r)
    points = numpy.array([[+r, zero], [-r, zero]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _c2_0a(data, dim):
    a = numpy.asarray(data)
    zero = numpy.zeros_like(a)
    points = numpy.array([[zero, +a], [zero, -a]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _centroid(data, dim):
    return numpy.full((3, 1), 1 / 3)


def _vertex(data, dim):
    return numpy.array([[1, 0, 0], [0, 1, 0], [0, 0, 1]])


def _d3_aa(a, dim):
    a = numpy.array(a)
    b = 1 - 2 * a
    return numpy.array([[a, a, b], [a, b, a], [b, a, a]])


def _d3_ab(data, dim):
    a, b = numpy.asarray(data)
    c = 1 - a - b
    points = numpy.array(
        [[a, b, c], [c, a, b], [b, c, a], [b, a, c], [c, b, a], [a, c, b]]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _c3_ab(data, dim):
    a, b = data
    c = 1 - a - b
    points = numpy.array([[a, b, c], [c, a, b], [b, c, a]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _swap_ab(data, dim):
    a, b = data
    c = 1 - a - b
    points = numpy.array([[a, b, c], [b, a, c]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _s2_static(a, dim):
    a = numpy.asarray(a)
    b = 1 - 2 * a
    points = numpy.array([[a, a, b]])
    points = numpy.moveaxis(points, 0, 1)
    return points


def _d(n, offset, r):
    import sympy

    cos = numpy.vectorize(sympy.cos)
    sin = numpy.vectorize(sympy.sin)

    alpha = (2 * numpy.arange(n) + offset) * sympy.pi / n
    cs = numpy.array([cos(alpha), sin(alpha)])
    points = numpy.multiply.outer(cs, r)
    return points


def _symm_r00(r, dim):
    zero = numpy.zeros_like(r)
    points = numpy.array(
        [
            [+r, zero, zero],
            [-r, zero, zero],
            [zero, +r, zero],
            [zero, -r, zero],
            [zero, zero, +r],
            [zero, zero, -r],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _symm_rr0(a, dim):
    z = numpy.zeros_like(a)
    points = numpy.array(
        [
            [+a, +a, z],
            [+a, z, +a],
            [z, +a, +a],
            [+a, -a, z],
            [+a, z, -a],
            [z, +a, -a],
            [-a, +a, z],
            [-a, z, +a],
            [z, -a, +a],
            [-a, -a, z],
            [-a, z, -a],
            [z, -a, -a],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _symm_rs0_roll(data, dim):
    r, s = data
    z = numpy.zeros_like(r)
    points = numpy.array(
        [
            [+r, +s, z],
            [+r, -s, z],
            [-r, +s, z],
            [-r, -s, z],
            [z, +r, +s],
            [z, +r, -s],
            [z, -r, +s],
            [z, -r, -s],
            [+s, z, +r],
            [+s, z, -r],
            [-s, z, +r],
            [-s, z, -r],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _symm_rrr(a, dim):
    points = numpy.array(
        [
            [+a, +a, +a],
            [-a, +a, +a],
            [+a, -a, +a],
            [-a, -a, +a],
            [+a, +a, -a],
            [-a, +a, -a],
            [+a, -a, -a],
            [-a, -a, -a],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _symm_rrs(data, dim):
    a, b = data
    points = numpy.array(
        [
            [+a, +a, +b],
            [+a, +b, +a],
            [+b, +a, +a],
            [+a, -a, +b],
            [+a, +b, -a],
            [+b, +a, -a],
            [-a, +a, +b],
            [-a, +b, +a],
            [+b, -a, +a],
            [-a, -a, +b],
            [-a, +b, -a],
            [+b, -a, -a],
            [+a, +a, -b],
            [+a, -b, +a],
            [-b, +a, +a],
            [+a, -a, -b],
            [+a, -b, -a],
            [-b, +a, -a],
            [-a, +a, -b],
            [-a, -b, +a],
            [-b, -a, +a],
            [-a, -a, -b],
            [-a, -b, -a],
            [-b, -a, -a],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _symm_rss_pm(data, dim):
    r, s = data
    points = numpy.array(
        [
            [+r, +s, +s],
            [+s, +r, +s],
            [+s, +s, +r],
            [-r, -s, -s],
            [-s, -r, -s],
            [-s, -s, -r],
        ]
    )
    points = numpy.moveaxis(points, 0, 1)
    return points


def _a(a, dim):
    assert a.shape == (1, 1)
    a = a[0][0]
    possible_vals = dim * [[+a, -a]]
    out = numpy.array(list(itertools.product(*possible_vals))).T
    return out


def _a0(a, dim):
    assert a.shape == (1, 1)
    a = a[0][0]
    entries = []
    for i in range(dim):
        entries += [
            i * [0] + [+a] + (dim - i - 1) * [0],
            i * [0] + [-a] + (dim - i - 1) * [0],
        ]
    return numpy.array(entries).T
