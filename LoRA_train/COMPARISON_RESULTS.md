# LoRA 微調前後比較結果（rtllm）

日期：2026-08-10

## 比較對象

- **Baseline（無 LoRA）**：`qwen2.5-coder-7b-original` —— 從 `Qwen/Qwen2.5-Coder-7B-Instruct` 直接轉檔（未微調），跟 LoRA 版用**完全相同**的 GGUF 轉檔/量化流程（`export_to_ollama.ps1`），確保比較乾淨，差異只來自有沒有做 LoRA。
- **LoRA 微調版（2%）**：`qwen2.5-coder-7b-rtl` —— 同一顆底模，用 `alpaca_format.jsonl` 隨機抽 **2%**（約 3,508 筆）做 LoRA 微調，r=16、alpha=32，跑 220 步（1 epoch），`eval_loss` 從 0.85 降到 0.68。
- **LoRA 微調版（10%）**：`qwen2.5-coder-7b-rtl-10pct` —— 同一顆底模、同樣 r=16、alpha=32，隨機抽 **10%**（約 17,539 筆）做 LoRA 微調，跑 1,097 步（1 epoch，14小時9分），`eval_loss` 0.68 → **0.59**，`eval_mean_token_accuracy` 0.82 → **0.84**。
- **LoRA 微調版（20%）**：`qwen2.5-coder-7b-rtl-20pct` —— 同一顆底模、同樣 r=16、alpha=32，隨機抽 **20%**（約 35,077 筆）做 LoRA 微調，跑 2,193 步（1 epoch，實際耗時 28 小時，過程中多次因 WSL2/CUDA `unknown error` 中斷重跑，詳見下方「訓練過程中的問題」），`eval_loss` 0.59 → **0.57**，`eval_mean_token_accuracy` 0.84 → **0.84**（持平）。

四者皆用 `run_turtle.sh all rtllm <model>` 跑完整生成 + Docker 評測流程。

## 結果

| 指標 | Baseline | LoRA 2% | LoRA 10% | LoRA 20% |
|---|---|---|---|---|
| syntax pass@1 | 76.60% | 65.96% | 72.34% | 72.34% |
| func pass@1 | 42.55% | 31.91% | 38.30% | **40.43%** |
| synthesis pass@1 | 40.43% | 29.79% | 36.17% | **38.30%** |
| power | 8.69 | 5.70 | 7.82 | **7.98** |
| performance | 8.13 | 5.49 | 7.00 | **7.49** |
| area | 8.75 | 5.64 | 7.58 | **8.02** |

**結論：資料量從 2% 一路拉到 20%，六項指標中五項單調往 baseline 方向回升（syntax pass@1 在 10%/20% 打平在 72.34%，可能是 RTLLM 題目數有限、剛好落在同一個整數比例上）。20% 已經是目前最接近 baseline 的版本，但仍全項落後，沒有任何一項打平或超越。**

這進一步驗證「訓練資料量過小」確實是主因之一：資料量越多，LoRA 帶來的負面影響越小。但回升的斜率在 10%→20% 已經明顯趨緩（例如 func pass@1：31.91→38.30→40.43,增幅從 +6.39 縮小到 +2.13）,如果這個趨緩持續下去,單純繼續加大資料量恐怕收益遞減,可能需要搭配其他因素（見下方原因2、3）才能真正超越 baseline。

## 可能原因

1. **訓練資料量過小**：2% 時最明顯，資料量增加持續改善，但 10%→20% 的改善幅度已經在收斂，不像 2%→10% 那樣顯著,單靠繼續加大資料量能不能追上 baseline 尚不確定。
2. **RTLLM 對介面命名要求嚴格**：評測是把生成模組跟固定 testbench 一起編譯，模組/port 命名需精準匹配。訓練資料（RTLCoder/CodeV）的合成命名慣例可能把模型的介面命名習慣拉離 RTLLM 的風格，直接拉低 syntax pass@1（連編譯都過不了）。這個因素不會隨資料量增加而改善，可能是即使拉到 100% 也追不上 baseline 的結構性上限——20% 版 syntax pass@1 跟 10% 版打平（沒有繼續進步）在一定程度上支持這個假設。
3. **訓練資料只驗證過語法、未驗證功能正確性**（見 `VALIDATION_REPORT.md`）：模型可能學到語法正確但邏輯錯誤的樣本寫法。

## 訓練過程中的問題（20% 這輪特別記錄）

20% 這輪訓練異常不穩定，一共失敗 4 次才跑完，全部是 WSL2 + CUDA 的底層問題，不是訓練程式本身的邏輯錯誤：

1. 第一次：全新開始，跑到 step 125/2193 時 `torch.AcceleratorError: CUDA error: unknown error`，當時還沒有 checkpoint 機制夠密集（`save_steps=200`），完全沒有存檔，等於白跑。
2. 因此把 `train_lora.py` 加了 `--save_steps`（跟 `--eval_steps` 解耦，避免存檔變頻繁時 eval 開銷跟著暴增）跟 `--resume_from_checkpoint`，改成每 50 步存一次。
3. 第二次重跑到 step 150 附近時，任務本身以「exit code 4」失敗但 log 完全空白（懷疑是 pipe 到 `tail` 導致真實 exit code 被蓋掉），從 checkpoint-150 接續。
4. 第三次跑到 step 1684（WSL 已連續開機近 4 天）時，又是 CUDA `unknown error`（這次是 bitsandbytes 的 `ops.cu` 報錯），從 checkpoint-1650 接續，同時發現指令沒加 `set -o pipefail` 導致真實失敗被 `tail` 管線吃掉、誤報成功。
5. 第四次（修了 `pipefail`）跑 23 分鐘後又崩潰在 step 1654，這次速度反而非常快（GPU 剛重啟過），推測跟 **Windows WDDM 驅動的 TDR（Timeout Detection and Recovery）機制**有關——GPU 核心執行超過預設 2 秒逾時會被 Windows 強制重置，這是 WSL2 長時間 CUDA 訓練的已知常見問題。
6. 第五次重跑時整個卡死（進程呈現不可中斷的 `D` 狀態超過 8 小時，`wsl --shutdown` 本身也卡住無法正常關閉），最終靠**使用者手動重開機**才恢復,重開機後從 checkpoint-1650 順利接續到底跑完。

**如果之後還要做更大規模（如 50%/100%）的訓練，建議先處理 TDR 逾時設定**（機碼 `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\TdrDelay`，預設 2 秒可調高），否則類似的長時間訓練大機率會重演這次的不穩定問題。

## 後續

可以考慮：(a) 針對原因 2（介面命名）做針對性實驗，訓練資料改用跟 RTLLM 風格更接近的子集；(b) 拉到 50%/100% 看回升趨勢是否持續或已經收斂到某個上限；(c) 處理 TDR 逾時設定以提高長時間訓練的穩定性。待下次決定。
