"""
Syntax-validate raw Verilog training samples with Icarus Verilog and emit
one normalized, deduplicated JSONL per source dataset.

This only checks that a sample COMPILES (`iverilog -g2012`). There is no
testbench for these training corpora, so this is a syntax check, not a
functional-correctness check like TuRTLe's benchmark evaluation.

Run inside WSL (needs the `iverilog` binary on PATH).
"""
import concurrent.futures
import csv
import itertools
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

csv.field_size_limit(2**31 - 1)

BASE = Path(__file__).resolve().parent.parent
TIMEOUT_SECONDS = 10


def check_syntax(code: str, worker_tmp: str) -> tuple[bool, str]:
    """Compile `code` standalone with iverilog. Returns (is_valid, error_text)."""
    src_path = os.path.join(worker_tmp, "sample.v")
    out_path = os.path.join(worker_tmp, "sample.out")
    with open(src_path, "w", encoding="utf-8", errors="ignore") as f:
        f.write(code)
    try:
        result = subprocess.run(
            ["iverilog", "-g2012", "-o", out_path, src_path],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return False, "timeout"
    if result.returncode == 0:
        return True, ""
    return False, result.stderr[:500]


def _worker_init():
    global _WORKER_TMP
    _WORKER_TMP = tempfile.mkdtemp(prefix="vverify_")


def _worker_check(record):
    is_valid, err = check_syntax(record["code"], _WORKER_TMP)
    record["valid"] = is_valid
    record["error"] = err
    return record


def iter_rtlcoder_27k():
    path = BASE / "RTL-Coder-27k" / "dataset" / "Resyn27k.json"
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            code = row["Response"][0] if row.get("Response") else None
            if code:
                yield {
                    "id": f"rtlcoder27k-{i}",
                    "source": "RTL-Coder-27k",
                    "instruction": row.get("Instruction"),
                    "code": code,
                }


def iter_rtlcoder_small():
    for variant, fname in [("7b", "randomized_filtered_data_7b.jsonl"), ("fixed", "randomized_filtered_data_fixed.jsonl")]:
        path = BASE / "RTL-Coder_small" / fname
        with open(path, encoding="utf-8") as f:
            for i, line in enumerate(f):
                line = line.strip()
                if not line:
                    continue
                row = json.loads(line)
                code = row.get("output")
                if code:
                    yield {
                        "id": f"rtlcoder-small-{variant}-{i}",
                        "source": "RTL-Coder_small",
                        "instruction": row.get("instruction"),
                        "code": code,
                    }


def iter_codev_all():
    path = BASE / "CodeV-All" / "codev-verilog.jsonl"
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            code = row.get("response")
            if code:
                yield {
                    "id": f"codev-{i}",
                    "source": "CodeV-All",
                    "instruction": row.get("instruction"),
                    "code": code,
                }


def iter_verigen_corpus():
    path = BASE / "VeriGen-GitHub-Corpus" / "Verilog_bigquery_GitHub.csv"
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        col = header.index("text")
        for i, row in enumerate(reader):
            code = row[col] if len(row) > col else None
            if code:
                yield {
                    "id": f"verigen-{i}",
                    "source": "VeriGen-GitHub-Corpus",
                    "instruction": None,
                    "code": code,
                }


DATASETS = {
    "RTL-Coder-27k": iter_rtlcoder_27k,
    "RTL-Coder_small": iter_rtlcoder_small,
    "CodeV-All": iter_codev_all,
    "VeriGen-GitHub-Corpus": iter_verigen_corpus,
}


def bounded_map(ex, fn, source_iter, max_in_flight):
    """True streaming map: never holds more than `max_in_flight` records in memory,
    unlike Executor.map() which eagerly submits (and thus fully materializes) its
    whole input before returning."""
    it = iter(source_iter)
    pending = set()
    for record in it:
        pending.add(ex.submit(fn, record))
        if len(pending) >= max_in_flight:
            break
    while pending:
        done, pending = concurrent.futures.wait(pending, return_when=concurrent.futures.FIRST_COMPLETED)
        for fut in done:
            yield fut.result()
        for record in itertools.islice(it, len(done)):
            pending.add(ex.submit(fn, record))


def run_dataset(name, iterator_fn, out_dir: Path, workers: int):
    print(f"[{name}] starting (bounded streaming, no full materialization)", flush=True)

    valid_count = 0
    invalid_count = 0
    done = 0
    valid_path = out_dir / f"{name}_valid.jsonl"
    invalid_path = out_dir / f"{name}_invalid.jsonl"

    with open(valid_path, "w", encoding="utf-8") as vf, open(invalid_path, "w", encoding="utf-8") as ivf:
        with concurrent.futures.ProcessPoolExecutor(max_workers=workers, initializer=_worker_init) as ex:
            for rec in bounded_map(ex, _worker_check, iterator_fn(), max_in_flight=workers * 4):
                done += 1
                is_valid = rec["valid"]
                if is_valid:
                    rec.pop("error", None)
                    valid_count += 1
                    vf.write(json.dumps(rec, ensure_ascii=False) + "\n")
                else:
                    invalid_count += 1
                    ivf.write(json.dumps(rec, ensure_ascii=False) + "\n")
                if done % 2000 == 0:
                    vf.flush()
                    ivf.flush()
                    print(f"[{name}] {done} checked ({valid_count} valid so far)", flush=True)

    print(f"[{name}] DONE: {valid_count} valid / {invalid_count} invalid / {done} total", flush=True)
    return {"total": done, "valid": valid_count, "invalid": invalid_count}


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    workers = min(os.cpu_count() or 4, 8)  # keep memory/process pressure modest on a 7.4GB WSL VM
    summary = {}
    for name, fn in DATASETS.items():
        if only and name != only:
            continue
        out_dir = BASE / name
        summary[name] = run_dataset(name, fn, out_dir, workers)

    summary_path = BASE / "scripts" / "validation_summary.json"
    existing = {}
    if summary_path.exists():
        with open(summary_path, encoding="utf-8") as f:
            existing = json.load(f)
    existing.update(summary)
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(existing, f, indent=2)
    print("=== SUMMARY ===")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
