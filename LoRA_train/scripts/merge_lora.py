"""
Merge a trained LoRA adapter back into its base model, producing a
standalone full-precision HF checkpoint that can be converted to GGUF
for Ollama (see export_to_ollama.sh).

Loads the base model in bf16 (NOT 4-bit) -- merging LoRA deltas into a
bitsandbytes-quantized model is possible in newer peft versions but is
less precise than merging against the original float weights, and this
is a one-off offline step so the extra VRAM/RAM cost doesn't matter.

Usage:
    python3 merge_lora.py \
        --base_model Qwen/Qwen2.5-Coder-7B-Instruct \
        --adapter ../checkpoints/qwen2.5-coder-7b-rtl-lora/final \
        --output ../merged/qwen2.5-coder-7b-rtl
"""
import argparse
import json
import os

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--base_model", default="Qwen/Qwen2.5-Coder-7B-Instruct")
    p.add_argument("--adapter", required=True, help="Path to the saved LoRA adapter (the .../final directory)")
    p.add_argument("--output", required=True, help="Directory to write the merged full-precision model")
    return p.parse_args()


def main():
    args = parse_args()

    print(f"Loading base model {args.base_model} in bf16 (not 4-bit -- merging needs float weights)...")
    # This machine only has 15GB total RAM (WSL capped at 7.4GB by default --
    # see TRAINING_GUIDE.md for the .wslconfig bump this needs). A 7B model in
    # bf16 is ~15GB, so even with more RAM given to WSL this can be tight.
    # offload_folder lets transformers spill layers to disk instead of OOMing
    # if physical+swap memory still isn't enough; low_cpu_mem_usage avoids an
    # extra full-size transient copy while loading.
    offload_dir = os.path.join(args.output, "_offload")
    os.makedirs(offload_dir, exist_ok=True)
    base_model = AutoModelForCausalLM.from_pretrained(
        args.base_model,
        dtype=torch.bfloat16,
        device_map="cpu",  # merging is a one-off CPU op; avoids competing with anything on the GPU
        trust_remote_code=True,
        low_cpu_mem_usage=True,
        offload_folder=offload_dir,
    )
    tokenizer = AutoTokenizer.from_pretrained(args.base_model, trust_remote_code=True)

    print(f"Loading LoRA adapter from {args.adapter}...")
    model = PeftModel.from_pretrained(base_model, args.adapter)

    print("Merging adapter into base weights...")
    merged = model.merge_and_unload()

    print(f"Saving merged model to {args.output}...")
    merged.save_pretrained(args.output, safe_serialization=True)
    tokenizer.save_pretrained(args.output)

    # This training venv's transformers (5.x) writes tokenizer_config.json with
    # "extra_special_tokens" as a list. llama.cpp's convert_hf_to_gguf.py runs
    # under its own pinned older transformers (4.57.6, see requirements-convert_hf_to_gguf.txt),
    # whose tokenizer loader expects that field to be a dict and crashes with
    # "'list' object has no attribute 'keys'" otherwise. The field is redundant
    # metadata (the actual special tokens are in added_tokens_decoder /
    # special_tokens_map.json), so drop it for cross-version compatibility.
    tokenizer_config_path = os.path.join(args.output, "tokenizer_config.json")
    with open(tokenizer_config_path, encoding="utf-8") as f:
        tok_config = json.load(f)
    if isinstance(tok_config.get("extra_special_tokens"), list):
        del tok_config["extra_special_tokens"]
        with open(tokenizer_config_path, "w", encoding="utf-8") as f:
            json.dump(tok_config, f, indent=2, ensure_ascii=False)
        print("Patched tokenizer_config.json: removed list-typed extra_special_tokens for GGUF-convert compatibility")

    print("Done.")


if __name__ == "__main__":
    main()
