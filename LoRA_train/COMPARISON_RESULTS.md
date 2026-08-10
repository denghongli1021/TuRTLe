# LoRA 微調前後比較結果（rtllm）

日期：2026-08-10

## 比較對象

- **Baseline（無 LoRA）**：`qwen2.5-coder-7b-original` —— 從 `Qwen/Qwen2.5-Coder-7B-Instruct` 直接轉檔（未微調），跟 LoRA 版用**完全相同**的 GGUF 轉檔/量化流程（`export_to_ollama.ps1`），確保比較乾淨，差異只來自有沒有做 LoRA。
- **LoRA 微調版**：`qwen2.5-coder-7b-rtl` —— 同一顆底模，用 `alpaca_format.jsonl` 隨機抽 **2%**（約 3,508 筆）做 LoRA 微調，r=16、alpha=32，跑 220 步（1 epoch），`eval_loss` 從 0.85 降到 0.68。

兩者皆用 `run_turtle.sh all rtllm <model>` 跑完整生成 + Docker 評測流程。

## 結果

| 指標 | Baseline | LoRA 微調版 | 差異 |
|---|---|---|---|
| syntax pass@1 | 76.60% | 65.96% | **-10.64** |
| func pass@1 | 42.55% | 31.91% | **-10.64** |
| synthesis pass@1 | 40.43% | 29.79% | **-10.64** |
| power | 8.69 | 5.70 | -2.99 |
| performance | 8.13 | 5.49 | -2.64 |
| area | 8.75 | 5.64 | -3.11 |

**結論：這次 LoRA 微調讓模型在 RTLLM 上全面變差，六項指標無一例外。**

## 可能原因

1. **訓練資料量過小**：僅 2%（3,508 筆、220 步），可能不足以學到有效的通用能力，反而只是對權重的擾動/雜訊。
2. **RTLLM 對介面命名要求嚴格**：評測是把生成模組跟固定 testbench 一起編譯，模組/port 命名需精準匹配。訓練資料（RTLCoder/CodeV）的合成命名慣例可能把模型的介面命名習慣拉離 RTLLM 的風格，直接拉低 syntax pass@1（連編譯都過不了）。
3. **訓練資料只驗證過語法、未驗證功能正確性**（見 `VALIDATION_REPORT.md`）：模型可能學到語法正確但邏輯錯誤的樣本寫法。

## 後續

原本規劃拉高到 10%/20% 資料量重跑看趨勢，10% 訓練已啟動但中途手動中止（未產生任何 checkpoint，無需清理）。是否要重新排程，待下次決定。
