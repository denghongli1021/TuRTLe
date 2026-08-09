"""
Convert merged_valid.jsonl into training-ready formats.

merged_valid.jsonl is heterogeneous: most rows have a natural-language
`instruction` (from RTL-Coder-27k / CodeV-All), but VeriGen-GitHub-Corpus
rows have no instruction (it's a raw scraped code corpus, no paired
description). Mixing the two into one Alpaca-style file would train the
model to emit code for an empty/missing instruction, which degrades
instruction-following. So this splits into two separate outputs:

  - alpaca_format.jsonl      : {instruction, input, output, source} - for SFT/LoRA instruction tuning
  - raw_code_pretrain.jsonl  : {text, source}                       - for continued pretraining (no instruction available)
"""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
IN_PATH = BASE / "merged_valid.jsonl"
ALPACA_PATH = BASE / "alpaca_format.jsonl"
PRETRAIN_PATH = BASE / "raw_code_pretrain.jsonl"


def main():
    n_alpaca = 0
    n_pretrain = 0
    by_source_alpaca = {}
    by_source_pretrain = {}

    with open(IN_PATH, encoding="utf-8") as fin, \
         open(ALPACA_PATH, "w", encoding="utf-8") as f_alpaca, \
         open(PRETRAIN_PATH, "w", encoding="utf-8") as f_pretrain:
        for line in fin:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            instruction = row.get("instruction")
            code = row["code"]
            source = row.get("source", "unknown")

            if instruction:
                f_alpaca.write(json.dumps({
                    "instruction": instruction.strip(),
                    "input": "",
                    "output": code,
                    "source": source,
                }, ensure_ascii=False) + "\n")
                n_alpaca += 1
                by_source_alpaca[source] = by_source_alpaca.get(source, 0) + 1
            else:
                f_pretrain.write(json.dumps({
                    "text": code,
                    "source": source,
                }, ensure_ascii=False) + "\n")
                n_pretrain += 1
                by_source_pretrain[source] = by_source_pretrain.get(source, 0) + 1

    print(json.dumps({
        "alpaca_format": {"total": n_alpaca, "by_source": by_source_alpaca, "path": str(ALPACA_PATH)},
        "raw_code_pretrain": {"total": n_pretrain, "by_source": by_source_pretrain, "path": str(PRETRAIN_PATH)},
    }, indent=2))


if __name__ == "__main__":
    main()
