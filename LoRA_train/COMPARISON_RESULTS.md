# LoRA 微調前後比較結果（rtllm）

日期：2026-08-10

## 比較對象

- **Baseline（無 LoRA）**：`qwen2.5-coder-7b-original` —— 從 `Qwen/Qwen2.5-Coder-7B-Instruct` 直接轉檔（未微調），跟 LoRA 版用**完全相同**的 GGUF 轉檔/量化流程（`export_to_ollama.ps1`），確保比較乾淨，差異只來自有沒有做 LoRA。
- **LoRA 微調版（2%）**：`qwen2.5-coder-7b-rtl` —— 同一顆底模，用 `alpaca_format.jsonl` 隨機抽 **2%**（約 3,508 筆）做 LoRA 微調，r=16、alpha=32，跑 220 步（1 epoch），`eval_loss` 從 0.85 降到 0.68。
- **LoRA 微調版（10%）**：`qwen2.5-coder-7b-rtl-10pct` —— 同一顆底模、同樣 r=16、alpha=32，隨機抽 **10%**（約 17,539 筆）做 LoRA 微調，跑 1,097 步（1 epoch，14小時9分），`eval_loss` 0.68 → **0.59**，`eval_mean_token_accuracy` 0.82 → **0.84**。

三者皆用 `run_turtle.sh all rtllm <model>` 跑完整生成 + Docker 評測流程。

## 結果

| 指標 | Baseline | LoRA 2% | LoRA 10% |
|---|---|---|---|
| syntax pass@1 | 76.60% | 65.96% | 72.34% |
| func pass@1 | 42.55% | 31.91% | 38.30% |
| synthesis pass@1 | 40.43% | 29.79% | 36.17% |
| power | 8.69 | 5.70 | 7.82 |
| performance | 8.13 | 5.49 | 7.00 |
| area | 8.75 | 5.64 | 7.58 |

**結論：LoRA 微調在兩個資料量下都讓模型在 RTLLM 上變差，但資料量從 2% 拉高到 10% 後，六項指標全部往 baseline 方向回升（差距明顯縮小，但尚未打平或超越）。**

這個趨勢支持「訓練資料量過小」是主要原因之一：2% 資料量太小,訓練帶來的效果更接近對權重的擾動/雜訊而非有效學習；資料量提升後這個副作用有緩解,但即使到 10% 仍未追上不訓練的 baseline。

## 可能原因

1. **訓練資料量過小**：2% 時最明顯，10% 已有改善但仍不足以超越 baseline，是否需要更多資料/更多 epoch 才能轉為正貢獻，尚待驗證。
2. **RTLLM 對介面命名要求嚴格**：評測是把生成模組跟固定 testbench 一起編譯，模組/port 命名需精準匹配。訓練資料（RTLCoder/CodeV）的合成命名慣例可能把模型的介面命名習慣拉離 RTLLM 的風格，直接拉低 syntax pass@1（連編譯都過不了）。這個因素不會隨資料量增加而改善，可能是即使拉到 20%/100% 也追不上 baseline 的結構性上限。
3. **訓練資料只驗證過語法、未驗證功能正確性**（見 `VALIDATION_REPORT.md`）：模型可能學到語法正確但邏輯錯誤的樣本寫法。

## 後續

可以考慮拉到 20% 資料量看趨勢是否持續往 baseline 靠近、甚至超越；也可以针對原因 2（介面命名）做針對性實驗，例如訓練資料改用跟 RTLLM 風格更接近的子集。待下次決定。
