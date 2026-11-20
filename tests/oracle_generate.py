"""Development-only black-box oracle capture. Never imported at runtime."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
for name in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[name] = "1"

parser = argparse.ArgumentParser()
parser.add_argument("--oracle", type=Path, required=True)
parser.add_argument("--kind", choices=("undid", "didint"), required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.oracle / "src"))
import numpy as np
import pandas as pd
from importlib import import_module

module = import_module(args.kind + "py")
outdir = Path(__file__).parent / "fixtures"
outdir.mkdir(exist_ok=True)
a = np.array([3, 3, 5, 5, 0, 0, 0, 0], dtype=float)
draws = np.array([np.roll(a, i) for i in range(1, 5)])
pd.DataFrame(draws).to_csv(outdir / "assignments.csv", index=False)
manifest = {
    "oracle": args.kind + "py",
    "head": subprocess.check_output(["git", "-C", str(args.oracle), "rev-parse", "HEAD"], text=True).strip(),
    "source_hashes": {
        str(p.relative_to(args.oracle)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted((args.oracle / "src").rglob("*.py"))
    },
    "license": "Historical Python numerical comparator; no source copied. Current comparator repository includes MIT license.",
    "scope": "Fresh small deterministic black-box comparisons, not full certification.",
}
for label in ("balanced", "unequal", "covariates", "strings"):
    rows = []
    for s in range(1, 9):
        for t in range(1, 7):
            n = 9 if label == "balanced" else 8 + (s + 2*t) % 6
            for j in range(n):
                x = (j - 3)/4 + .12*t + .07*s + np.sin(j+s*t)/5
                x2 = np.cos(j*.8+s) + j*j/40 + .05*t
                y = .3*s + .2*t + np.sin(s*t)*.08 + .5*x + .2*x2
                y += .07*s*x + .03*t*x + .025*t*s*x2
                y += (a[s-1] > 0 and t >= a[s-1])*(1 + s*.12 + t*.03)
                y += np.cos(2*j+s+t)*.11
                rows.append((f"S{s:02}" if label == "strings" else s, t, j, a[s-1], x, x2, y))
    d = pd.DataFrame(rows, columns=["s", "t", "j", "g", "x", "x2", "y"])
    d.to_csv(outdir / (label + ".csv"), index=False, float_format="%.17g")
    covs = ["x", "x2"] if label == "covariates" else []
    design = module.Design(d, outcome="y", cluster="s", time="t", assignment=a, covariates=covs)
    jk = design.jackknife(engine="reference")
    assert jk["diagnostics"]["status"] == "ok"
    ri = design.randomization_inference(assignments=draws, engine="reference")
    inner = [design.jackknife(assignment=b, engine="reference") for b in draws]
    assert all(x["diagnostics"]["status"] == "ok" for x in inner)
    tj = np.array([x["statistic"] for x in inner])
    tol = 64*np.finfo(float).eps*np.maximum(1, np.maximum(abs(tj), abs(jk["statistic"])))
    hits = int(np.sum(abs(tj) >= abs(jk["statistic"])-tol))
    summary = dict(estimate=jk["estimate"], se=jk["standard_error"],
                   statistic=jk["statistic"], p=jk["p_value"],
                   ri_beta_p=ri["p_value"], ri_beta_hits=ri["hits"],
    # The historical replace procedure compares Student-t p-values; with fixed
    # G this is the same ordering as the absolute jackknife t statistics.
    historical = design.placebo_replace(assignments=draws, engine="reference")
    pd.DataFrame([summary]).to_csv(outdir / (label + "_summary.csv"), index=False, float_format="%.17g")
    pd.DataFrame({"deleted": jk["delete_estimates"]}).to_csv(outdir / (label + "_deleted.csv"), index=False, float_format="%.17g")
    pd.DataFrame({"beta": ri["statistics"], "tj": tj}).to_csv(outdir / (label + "_draws.csv"), index=False, float_format="%.17g")
    pd.DataFrame([x["delete_estimates"] for x in inner]).to_csv(outdir / (label + "_inner.csv"), index=False, float_format="%.17g")
    if args.kind == "didint" and covs:
        fitted = import_module("didintpy.fitted_didint")
        ccc_results = []
        for ccc in ("hom", "state", "time", "int"):
            fit = fitted.prepare_fitted_first_stage(d, outcome_col="y", state_col="s", time_col="t", gvar_col="g", covariates=covs, ccc=ccc)
            core = fitted.run_fitted_core(fit, fit.panel)
            ccc_results.append({"ccc": ccc, "estimate": core["att"]["estimate"]})
        pd.DataFrame(ccc_results).to_csv(outdir / "ccc.csv", index=False, float_format="%.17g")
(outdir / "provenance.json").write_text(json.dumps(manifest, indent=2)+"\n")
print("Captured 4 fixtures, 4 assignments each, every observed and randomized deletion.")
