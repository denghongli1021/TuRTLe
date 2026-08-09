"""
Merge each dataset's *_valid.jsonl (syntax-verified via iverilog) into one
deduplicated JSONL for LoRA training. Dedup is by exact code-string hash,
first occurrence wins, in the source order listed below.
"""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent

SOURCES = [
    ("RTL-Coder-27k", BASE / "RTL-Coder-27k" / "RTL-Coder-27k_valid.jsonl"),
    ("RTL-Coder_small", BASE / "RTL-Coder_small" / "RTL-Coder_small_valid.jsonl"),
    ("CodeV-All", BASE / "CodeV-All" / "CodeV-All_valid.jsonl"),
    ("VeriGen-GitHub-Corpus", BASE / "VeriGen-GitHub-Corpus" / "VeriGen-GitHub-Corpus_valid.jsonl"),
]

OUT_PATH = BASE / "merged_valid.jsonl"


def main():
    seen_hashes = set()
    per_source = {}
    total_in = 0
    total_out = 0

    with open(OUT_PATH, "w", encoding="utf-8") as out:
        for name, path in SOURCES:
            if not path.exists():
                print(f"[skip] {name}: {path} not found")
                continue
            kept = 0
            seen = 0
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    seen += 1
                    row = json.loads(line)
                    code_hash = hashlib.sha256(row["code"].encode("utf-8", errors="ignore")).hexdigest()
                    if code_hash in seen_hashes:
                        continue
                    seen_hashes.add(code_hash)
                    out.write(json.dumps(row, ensure_ascii=False) + "\n")
                    kept += 1
            total_in += seen
            total_out += kept
            per_source[name] = {"input_valid": seen, "kept_after_dedup": kept, "dropped_as_duplicate": seen - kept}
            print(f"[{name}] {seen} valid -> {kept} kept after cross-dataset dedup", flush=True)

    print("\n=== MERGE SUMMARY ===")
    print(json.dumps({"per_source": per_source, "total_input_valid": total_in, "total_merged": total_out}, indent=2))
    print(f"\nWrote {total_out} rows to {OUT_PATH}")


if __name__ == "__main__":
    main()
