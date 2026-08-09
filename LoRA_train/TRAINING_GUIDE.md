# LoRA 訓練指南

## 硬體現況（很重要，請先讀）

這台機器的 GPU 是 **RTX 5050，只有 8151MiB（約 8GB）VRAM**，而且目前這 8GB 裡有 **~7.8GB 被 Ollama 佔用**（`llama-server.exe` 常駐在記憶體裡）。這代表：

1. **跑訓練前一定要先關掉 Ollama**，不然一啟動就會 CUDA OOM：
   ```powershell
   taskkill /f /im "ollama*"
   taskkill /f /im "llama-server.exe"
   ```
2. 8GB VRAM 對 7B 模型來說非常吃緊，只能用 **QLoRA（4-bit 量化）**，不可能用一般 LoRA（fp16/bf16 載入整個 7B 模型至少要 14GB+）。訓練腳本已經預設用 4-bit NF4 量化 + gradient checkpointing + `paged_adamw_8bit` optimizer，這些都是為了把記憶體壓到 8GB 以內的必要設定，不要隨意關掉。
3. 即使做了這些優化，**還是有機會 OOM**——如果發生，優先調整順序：`--max_seq_length` 調小（預設 1024）→ `--gradient_accumulation_steps` 調大、`--per_device_train_batch_size` 維持 1 不動 → 換更小的 base model（例如 3B 級別）。

## 訓練腳本

[`scripts/train_lora.py`](scripts/train_lora.py) 對 `alpaca_format.jsonl`（178,966 筆有 instruction 的樣本）做 QLoRA 監督式微調（SFT），**不是**用 `raw_code_pretrain.jsonl` 續訓——這兩份資料的差異跟為什麼要分開，前面對話已經解釋過（沒有 instruction 的資料如果拿去做 SFT，會傷害模型的指令遵循能力）。如果之後也想做續訓那一步，需要另外寫一支續訓腳本，目前這支只處理指令微調。

### 執行方式

```bash
# 在 WSL 裡（腳本用到的 bitsandbytes/flash-attn 生態在 Linux 上支援度遠比 Windows 原生好）
source ~/lora_train_venv/bin/activate
cd /mnt/c/Users/dengh/Documents/code/TuRTLe/LoRA_train/scripts

# 先跑個 smoke test，確認環境沒問題、不會 OOM，20 步大概幾分鐘內就能看到結果
python3 train_lora.py --max_steps 20

# 確認沒問題後，跑正式訓練（預設 3 epoch，時間會長很多）
python3 train_lora.py
```

### 關鍵參數說明

| 參數 | 預設值 | 為什麼這樣設 |
|---|---|---|
| `--base_model` | `Qwen/Qwen2.5-Coder-7B-Instruct` | 對應你目前用 Ollama 跑的 qwen2.5-coder:7b。**注意**：這是從 HuggingFace 下載原始 bf16 權重（約 15GB），不是 Ollama 的 GGUF 檔——GGUF 沒辦法直接拿來做 LoRA 訓練，量化是腳本載入後即時做的，所以無論如何都要下載這 15GB。 |
| `--max_length` | 1024 | Verilog 模組通常不長，1024 token 大部分夠用；如果訓練 log 一直出現截斷警告，可以調大，但會吃更多 VRAM。 |
| `--per_device_train_batch_size` | 1 | 8GB VRAM 下能穩定塞進去的批次大小上限，基本上不建議調大。 |
| `--gradient_accumulation_steps` | 16 | 用梯度累積模擬 batch size 16，彌補上面 batch size=1 的統計不穩定性，不吃額外 VRAM。 |
| `--lora_r` / `--lora_alpha` | 16 / 32 | 常見預設組合（alpha = 2×r），r 越大可訓練參數越多、越接近全量微調效果，但也越吃記憶體/越容易過擬合小資料集。 |
| `--eval_fraction` | 0.02 | 從 `alpaca_format.jsonl` 切 2%（約 3,580 筆）當 held-out 驗證集，**訓練過程中完全不會被拿去算 loss 更新權重**，只用來監控 eval loss 有沒有隨訓練上升（過擬合訊號）。 |

### 這裡的 `--eval_fraction` 跟你研究設計裡的 held-out 是兩件事，別搞混

`--eval_fraction` 切出來的驗證集，來源還是 `alpaca_format.jsonl` 本身（RTL-Coder-27k + CodeV-All），用途是**訓練過程中的過擬合監控**（eval loss 曲線）。這**不等於**我們之前討論你的 LoRA 迭代研究設計時提到的「凍結評測集」——那個講的是「訓練資料跟 TuRTLe benchmark（RTLLM/VerilogEval）評測資料要分開，避免資料洩漏」，是完全不同層級的保證。這支訓練腳本產出的 LoRA adapter，拿去跑 TuRTLe 評測之前，那層資料洩漏的把關還是要你自己確認 `alpaca_format.jsonl` 裡沒有混進 benchmark 本身的題目（目前這幾個訓練資料集本來就跟 TuRTLe 的 benchmark 是不同來源，理論上沒有重疊，但沒有做過交叉比對確認）。

## 訓練完之後

LoRA adapter 會存在 `--output_dir` 底下的 `final/` 資料夾（預設 `LoRA_train/checkpoints/qwen2.5-coder-7b-rtl-lora/final/`）。這只是 adapter 權重（幾十到幾百 MB），不是完整模型，推論時有兩種用法：

1. **用 `peft` 動態載入**：base model + `PeftModel.from_pretrained(base_model, adapter_path)`，不用合併，方便切換/比較不同 adapter。
2. **合併成完整模型**（`merge_and_unload()`）：適合要匯出成 GGUF 給 Ollama 用的情境——之後如果你想讓微調後的模型也能像 qwen2.5-coder:7b 一樣透過 Ollama 跑 TuRTLe 評測，就需要這一步 + 額外轉檔（`llama.cpp` 的 convert 腳本）。這支腳本目前**沒有**做合併/轉檔，只到存 adapter 為止。

## 已知風險 / 尚未處理的部分

- 只做了單輪 SFT，沒有實作我們之前討論的「自我修正 + 迭代 LoRA」那整套閉環（生成失敗題目 → 收集 error → 再訓練）——這支腳本是那個更大架構裡「一輪訓練」的積木，不是完整流程。
- 沒有處理 `alpaca_format.jsonl` 跟 TuRTLe benchmark 之間潛在的資料重疊（見上方說明）。
- 8GB VRAM 真的偏緊，如果 smoke test 就 OOM，下一步應該考慮換 3B 級模型（如 Qwen2.5-Coder-3B-Instruct）而不是持續調參數硬做。
