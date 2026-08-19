"""
QLoRA fine-tuning on alpaca_format.jsonl (instruction -> Verilog code).

Tuned for a single ~8GB-VRAM GPU (this machine: RTX 5050, 8151MiB total):
4-bit NF4 quantized base model + LoRA adapters + gradient checkpointing +
paged 8-bit optimizer + small per-device batch with gradient accumulation.

IMPORTANT: this GPU has only 8GB VRAM and it is normally almost entirely
occupied by Ollama (~7.8GB used by llama-server.exe holding qwen2.5-coder:7b
in memory). You MUST stop Ollama before running this script:
    taskkill /f /im "ollama*"
    taskkill /f /im "llama-server.exe"
(run from PowerShell/cmd.txt, not from inside WSL)

Usage:
    python3 train_lora.py \
        --data ../alpaca_format.jsonl \
        --base_model Qwen/Qwen2.5-Coder-7B-Instruct \
        --output_dir ../checkpoints/qwen2.5-coder-7b-rtl-lora \
        --max_steps 100   # smoke test; omit for a full run driven by --num_train_epochs
"""
import argparse
import json
import os

import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
)
from trl import SFTConfig, SFTTrainer


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--data", default="../alpaca_format.jsonl", help="Path to the alpaca-format JSONL")
    p.add_argument("--base_model", default="Qwen/Qwen2.5-Coder-7B-Instruct")
    p.add_argument("--output_dir", default="../checkpoints/qwen2.5-coder-7b-rtl-lora")
    p.add_argument("--data_fraction", type=float, default=1.0, help="Randomly sample this fraction (0-1] of the training data before splitting off eval. Use this to control total training time -- e.g. 0.05 for a fast ~9k-row run.")
    p.add_argument("--max_length", type=int, default=1024, help="Verilog modules are usually short; raise if you see truncation warnings and have VRAM to spare")
    p.add_argument("--lora_r", type=int, default=16)
    p.add_argument("--lora_alpha", type=int, default=32)
    p.add_argument("--lora_dropout", type=float, default=0.05)
    p.add_argument("--per_device_train_batch_size", type=int, default=1)
    p.add_argument("--gradient_accumulation_steps", type=int, default=16)
    p.add_argument("--learning_rate", type=float, default=2e-4)
    p.add_argument("--num_train_epochs", type=float, default=3.0)
    p.add_argument("--max_steps", type=int, default=-1, help="Set to a small number (e.g. 20) for a smoke test; -1 = full run driven by num_train_epochs")
    p.add_argument("--eval_fraction", type=float, default=0.02, help="Fraction of data held out as eval (never trained on)")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--logging_steps", type=int, default=10)
    p.add_argument("--save_steps", type=int, default=200, help="Checkpoint frequency. Lower this on long runs to cap how much progress a crash can lose.")
    p.add_argument("--eval_steps", type=int, default=200, help="Eval frequency. Kept separate from --save_steps since each eval pass costs several minutes -- lowering save_steps for crash-safety shouldn't multiply eval overhead too.")
    p.add_argument("--resume_from_checkpoint", default=None, help="Path to a checkpoint-N directory (e.g. ../checkpoints/.../checkpoint-200) to resume an interrupted run from.")
    return p.parse_args()


CHAT_SYSTEM_PROMPT = (
    "You are an expert Verilog/SystemVerilog RTL designer. "
    "Given a design specification, respond with only the complete Verilog module."
)


def format_example(example, tokenizer):
    messages = [
        {"role": "system", "content": CHAT_SYSTEM_PROMPT},
        {"role": "user", "content": example["instruction"]},
        {"role": "assistant", "content": example["output"]},
    ]
    return {"text": tokenizer.apply_chat_template(messages, tokenize=False)}


def main():
    args = parse_args()

    free_bytes, total_bytes = torch.cuda.mem_get_info() if torch.cuda.is_available() else (0, 0)
    print(f"GPU free VRAM: {free_bytes / 1e9:.2f} GB / {total_bytes / 1e9:.2f} GB total")
    if torch.cuda.is_available() and free_bytes < 5e9:
        print(
            "WARNING: less than 5GB free VRAM. On this 8GB card that almost always means "
            "Ollama (or something else) is still holding GPU memory. Stop it first:\n"
            '  taskkill /f /im "ollama*"\n'
            '  taskkill /f /im "llama-server.exe"\n'
            "Continuing anyway, but expect a CUDA OOM."
        )

    tokenizer = AutoTokenizer.from_pretrained(args.base_model, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
    )
    model = AutoModelForCausalLM.from_pretrained(
        args.base_model,
        quantization_config=bnb_config,
        device_map="auto",
        trust_remote_code=True,
    )
    model.config.use_cache = False
    model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)

    lora_config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    dataset = load_dataset("json", data_files=args.data, split="train")
    if args.data_fraction < 1.0:
        total = len(dataset)
        n = max(1, int(total * args.data_fraction))
        dataset = dataset.shuffle(seed=args.seed).select(range(n))
        print(f"--data_fraction={args.data_fraction}: sampled {n} / {total} rows for training+eval")
    dataset = dataset.map(lambda ex: format_example(ex, tokenizer), remove_columns=dataset.column_names)
    split = dataset.train_test_split(test_size=args.eval_fraction, seed=args.seed)
    train_dataset, eval_dataset = split["train"], split["test"]
    print(f"train: {len(train_dataset)} rows, eval (held out, never trained on): {len(eval_dataset)} rows")

    sft_config = SFTConfig(
        output_dir=args.output_dir,
        max_length=args.max_length,
        per_device_train_batch_size=args.per_device_train_batch_size,
        per_device_eval_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        learning_rate=args.learning_rate,
        num_train_epochs=args.num_train_epochs,
        max_steps=args.max_steps,
        bf16=True,
        optim="paged_adamw_8bit",
        logging_steps=args.logging_steps,
        save_steps=args.save_steps,
        save_total_limit=3,
        eval_strategy="steps",
        eval_steps=args.eval_steps,
        report_to="none",
        seed=args.seed,
        dataset_text_field="text",
        packing=False,
    )

    trainer = SFTTrainer(
        model=model,
        args=sft_config,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        processing_class=tokenizer,
    )

    trainer.train(resume_from_checkpoint=args.resume_from_checkpoint)

    final_dir = os.path.join(args.output_dir, "final")
    trainer.model.save_pretrained(final_dir)
    tokenizer.save_pretrained(final_dir)
    print(f"Saved LoRA adapter to {final_dir}")


if __name__ == "__main__":
    main()
