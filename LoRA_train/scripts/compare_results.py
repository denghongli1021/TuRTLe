"""
Compare two TuRTLe detail_report_<task>.json files (e.g. baseline vs. LoRA-tuned
model on the same task) and print a side-by-side table with deltas.

Usage:
    python3 compare_results.py \
        --baseline ../../results/qwen2.5-coder_7b/rtllm/detail_report_rtllm.json \
        --tuned ../../results/qwen2.5-coder-7b-rtl/rtllm/detail_report_rtllm.json \
        --task rtllm
"""
import argparse
import json


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--baseline", required=True, help="detail_report json for the model WITHOUT LoRA")
    p.add_argument("--tuned", required=True, help="detail_report json for the LoRA-tuned model")
    p.add_argument("--task", required=True, help="Task key inside the report json, e.g. rtllm")
    return p.parse_args()


def flatten(d, prefix=""):
    """Flatten nested dicts of scalars into {'syntax.pass@1': 92.5, ...}."""
    out = {}
    for k, v in d.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            out.update(flatten(v, prefix=f"{key}."))
        elif isinstance(v, (int, float)):
            out[key] = v
    return out


def main():
    args = parse_args()

    with open(args.baseline, encoding="utf-8") as f:
        baseline = json.load(f)
    with open(args.tuned, encoding="utf-8") as f:
        tuned = json.load(f)

    if args.task not in baseline or args.task not in tuned:
        raise KeyError(
            f"Task '{args.task}' not found in one of the reports. "
            f"baseline keys: {list(baseline.keys())}, tuned keys: {list(tuned.keys())}"
        )

    base_metrics = flatten(baseline[args.task])
    tuned_metrics = flatten(tuned[args.task])
    all_keys = sorted(set(base_metrics) | set(tuned_metrics))

    base_model = baseline.get("config", {}).get("model", "baseline")
    tuned_model = tuned.get("config", {}).get("model", "tuned")

    print(f"Task: {args.task}")
    print(f"Baseline: {base_model}")
    print(f"Tuned:    {tuned_model}")
    print()
    header = f"{'metric':<24} {'baseline':>12} {'tuned':>12} {'delta':>12}"
    print(header)
    print("-" * len(header))
    for key in all_keys:
        b = base_metrics.get(key)
        t = tuned_metrics.get(key)
        if b is None or t is None:
            delta_str = "n/a"
        else:
            delta = t - b
            sign = "+" if delta >= 0 else ""
            delta_str = f"{sign}{delta:.2f}"
        b_str = f"{b:.2f}" if isinstance(b, (int, float)) else "n/a"
        t_str = f"{t:.2f}" if isinstance(t, (int, float)) else "n/a"
        print(f"{key:<24} {b_str:>12} {t_str:>12} {delta_str:>12}")


if __name__ == "__main__":
    main()
