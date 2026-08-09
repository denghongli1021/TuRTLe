# LoRA 訓練資料集：下載、驗證與格式轉換報告

日期：2026-08-09

## 目標

從公開的 Verilog LLM 訓練資料集中，篩選出「保證能編譯通過」的樣本，作為 LoRA 微調語料，並輸出成可直接餵給訓練腳本的格式。

## 資料來源

| 資料夾 | 來源 | 原始筆數 |
|---|---|---|
| `RTL-Coder-27k/` | [hkust-zhiyao/RTL-Coder](https://github.com/hkust-zhiyao/RTL-Coder)（GitHub，`Resyn27k.json`） | 26,532 |
| `RTL-Coder_small/` | [Nellyw888/RTL-Coder_small](https://huggingface.co/datasets/Nellyw888/RTL-Coder_small)（HF） | 2,649（`_7b.jsonl` 1,310 + `_fixed.jsonl` 1,339） |
| `CodeV-All/` | [yang-z/CodeV-All-dataset](https://huggingface.co/datasets/yang-z/CodeV-All-dataset)（HF，僅取 `codev-verilog.jsonl`，排除 Chisel） | 165,340 |
| `VeriGen-GitHub-Corpus/` | [shailja/Verilog_GitHub](https://huggingface.co/datasets/shailja/Verilog_GitHub)（HF，VeriGen 論文語料） | 108,971 |
| `MG-Verilog/` | [GaTech-EIC/MG-Verilog](https://huggingface.co/datasets/GaTech-EIC/MG-Verilog)（HF） | 11,144 |

## 驗證方法

用 Icarus Verilog（`iverilog -g2012`）對每筆樣本的程式碼做**獨立編譯檢查**（無 testbench）。這代表：

- ✅ 驗證的是**語法/elaboration 正確性**（能不能編譯過）
- ❌ **不是**功能正確性——這些訓練資料集沒有配對的 testbench，無法像 TuRTLe 評測 benchmark 那樣驗證行為是否符合規格

驗證腳本：[`scripts/validate_and_build_jsonl.py`](scripts/validate_and_build_jsonl.py)，在 WSL（Ubuntu）內執行，每筆樣本寫入獨立暫存檔後呼叫 `iverilog`，逾時 10 秒視為失敗，多進程平行處理。

### `iverilog` vs. `vvp`：只驗證了「編譯」，沒有驗證「執行」

Icarus Verilog 工具鏈其實分兩個階段：

1. **`iverilog`（編譯）**：把原始碼 parse + elaborate，編譯成中介格式（bytecode）。這步只確認語法/elaboration 過不過，**不會實際執行任何東西**，就像 `gcc -c` 只編出目的檔。
2. **`vvp`（執行/模擬）**：把編譯結果實際跑起來——處理 `initial` block、時鐘觸發、testbench 的比對邏輯、`$finish` 等。

**這次的驗證只做到第 1 步，完全沒有呼叫 `vvp`**，原因是這些訓練資料集沒有配對的 testbench 可以驅動模擬，跑 `vvp` 也無從判斷「輸出對不對」。這帶來兩個實際後果：

- **有可能有樣本編譯過、但真的拿去跑 `vvp` 會 crash 或掛住**：iverilog 的靜態編譯不會抓到所有問題，有些錯誤（陣列存取越界、特定訊號驅動下才觸發的 hierarchical reference 問題等）只有在真正執行時才會浮現。目前 `merged_valid.jsonl` 裡沒有排除這類樣本。
- **更重要的是：能編譯過、能跑不代表邏輯是對的**。像 bit width 算錯、reset 極性反了、sensitivity list 漏訊號、blocking/non-blocking 賦值用錯這類問題，都不是語法錯誤，iverilog 抓不到，**必須要有 testbench 比對預期輸出才抓得出來**。這批訓練資料完全沒有這層保障，等於是「保證編譯過」而非「保證正確」——跟 RTLCoder 官方自己聲明「不保證資料正確」是同一個限制。

可以額外加一層「對每個編譯通過的樣本跑 `vvp`（設定逾時），踢掉會 crash/hang 的」當作 smoke test，能再篩掉一批「編譯過但實際會炸」的樣本；但因為沒有 testbench，這層 smoke test 依然無法驗證邏輯正確性。這次先沒有做這一層（見下方「已知限制」）。

## 各資料集驗證結果

| 資料集 | 總筆數 | 通過 | 未通過 | 通過率 |
|---|---|---|---|---|
| RTL-Coder-27k | 26,532 | 15,909 | 10,623 | 60.0% |
| RTL-Coder_small | 2,649 | 2,395 | 254 | 90.4% |
| CodeV-All | 165,340 | 164,352 | 988 | 99.4% |
| VeriGen-GitHub-Corpus | 108,971 | 43,253 | 65,718 | 39.7% |
| **合計（已驗證的 4 個）** | **303,492** | **225,909** | **77,583** | **74.4%** |
| MG-Verilog | 11,144 | — 未驗證，見下 | — | — |

每個資料夾底下都有 `<name>_valid.jsonl` 與 `<name>_invalid.jsonl`（後者保留 iverilog 的錯誤訊息，可用於錯誤分析）。抽查過幾筆 invalid 樣本，確認錯誤都是真實的語法/elaboration 問題（例如對 wire 做非法賦值、引用未定義的子模組），不是驗證流程本身的誤判。

### 通過率為什麼差這麼多

- **CodeV-All（99.4%）最高**：其資料建構方式是「反向指令生成」——先拿真實存在的 GitHub Verilog 程式碼，再用 LLM 幫它生成描述。程式碼本身是真的，天生就編得過。
- **RTL-Coder 系列（60~90%）**：資料是用 GPT-3.5 從頭生成指令再生成程式碼（全合成），官方本身就註明不保證正確性。
- **VeriGen 語料（39.7%）最低**：是未經篩選、直接從 GitHub 爬回來的完整檔案，大量參考外部未定義的廠商 IP 模組（如 Xilinx `processing_system7_v5_5_*`）、或包含非標準/不完整片段，單獨編譯自然容易失敗。

## MG-Verilog 為何沒有驗證

檢查 MG-Verilog 的 schema（欄位：`code`, `description`）後發現，`code` 欄位是**只有函式主體的程式碼片段**，沒有 `module`/port 宣告（對應它的 instruction 明確要求「不要包含 module、輸入輸出定義」）。這種片段單獨丟給 iverilog 一定會噴一堆假錯誤（缺變數宣告、缺 port），驗證沒有意義。

處理方式：轉成 `MG-Verilog/mg_verilog_unvalidated.jsonl`（11,144 筆），保留但不參與語法驗證，也**不納入**最終合併的訓練資料。如需使用，需另外設計驗證方式（例如比對是否為某個完整檔案的子片段）。

## 過程中遇到的問題與解決方式

### 1. Windows Python 的 CSV 欄位大小限制 overflow

**問題**：`csv.field_size_limit(sys.maxsize)` 在 Windows 上會噴 `OverflowError: Python int too large to convert to C long`，因為 Windows 上 C 的 `long` 是 32-bit，即使是 64-bit Python 也一樣。
**解決**：改用 `csv.field_size_limit(2**31 - 1)`，明確控制在 32-bit 有號整數範圍內。

### 2. RTLCoder 的 `Response` 欄位是 list 不是字串

**問題**：`Resyn27k.json` 裡每筆的 `Response` 是一個列表（雖然抽查 2000 筆長度都是 1），直接當字串用會出錯。
**解決**：取 `Response[0]`。

### 3. WSL 記憶體不足，背景任務被砍掉（exit code 15）

**問題**：第一版驗證腳本對每個資料集都是 `records = list(iterator_fn())` 整份讀進記憶體，再建一個 `by_id` dict、再建一個 `tasks` list——同一份資料同時存在記憶體裡 3 份。處理 CodeV-All（269MB JSONL）到 VeriGen 語料（1.9GB CSV）時，WSL 的虛擬機只分到 7.4GB RAM（`free -h` 確認），直接被系統砍掉，且一度連 `wsl.exe` 本身都回應異常（`Wsl/Service/E_UNEXPECTED`），需要 `wsl --shutdown` 重置。

**解決**：重寫成真正的串流處理（`bounded_map()`，見 [`scripts/validate_and_build_jsonl.py`](scripts/validate_and_build_jsonl.py)）：任何時刻最多只有 `workers × 4`（約 32）筆樣本停留在記憶體中。

**一個容易誤踩的細節**：原本以為改用 `ProcessPoolExecutor.map(fn, generator, chunksize=N)` 就能解決，但實際上 `concurrent.futures.Executor.map()` 內部是 `fs = [self.submit(fn, *args) for args in ...]`——這一行會**立刻、同步地把整個輸入 iterable 消耗完**才回傳結果的 generator，並不是邊讀邊算的惰性求值。要做到真正的串流，必須自己用 `executor.submit()` + `concurrent.futures.wait(..., return_when=FIRST_COMPLETED)` 手動控制「同時在跑的任務數上限」，才能確保記憶體用量有上界。

**修復後**：三個資料集（含重跑的 RTL-Coder-27k 已完成部分無需重跑）都順利跑完，沒有再發生記憶體問題。也把平行 worker 數從 `os.cpu_count()`（16）降到 `min(cpu_count, 8)`，降低對 WSL 資源的壓力。

## 跨資料集去重（Deduplication）

合併前先用程式碼內容的 SHA-256 雜湊比對，去除跨資料集重複的樣本（保留第一次出現的），意外發現兩個有意思的結果：

| 資料集 | 驗證通過 | 去重後保留 | 被判定為重複 |
|---|---|---|---|
| RTL-Coder-27k | 15,909 | 15,841 | 68 |
| RTL-Coder_small | 2,395 | **0** | **2,395（100%）** |
| CodeV-All | 164,352 | 164,349 | 3 |
| VeriGen-GitHub-Corpus | 43,253 | 20,380 | 22,873（52.9%） |
| **合計** | **225,909** | **200,570** | **25,339** |

- **RTL-Coder_small 100% 重複**：證實它就是 RTL-Coder-27k 的篩選子集，不是獨立資料，去重後完全消失是預期結果，不是 bug。
- **VeriGen 語料超過一半跟 CodeV-All 重複**：兩者都是各自獨立爬 GitHub 抓 Verilog 檔案，抓到大量相同的熱門開源 IP（FIFO、UART 等常見模組），這也解釋了為什麼原本估計 VeriGen 語料「乾淨額外貢獻」的量會比預期少。

合併結果：`merged_valid.jsonl`（**200,570 筆**，449MB）。

## 訓練格式轉換

`merged_valid.jsonl` 裡有兩種性質不同的資料，混在一起訓練不合適：

- 大部分樣本有自然語言 `instruction`（來自 RTL-Coder-27k / CodeV-All）
- VeriGen 語料（以及 CodeV-All 裡少數 1,224 筆）沒有 instruction，只是原始程式碼

如果把沒有 instruction 的樣本硬塞進 Alpaca 格式（instruction 留空），會讓模型學到「看到空白指令也要生成程式碼」，反而傷害模型的 instruction-following 能力。所以拆成兩個檔案（腳本：[`scripts/build_training_format.py`](scripts/build_training_format.py)）：

| 檔案 | 用途 | 格式 | 筆數 | 大小 |
|---|---|---|---|---|
| `alpaca_format.jsonl` | SFT / LoRA 指令微調 | `{"instruction", "input": "", "output", "source"}` | 178,966 | 288MB |
| `raw_code_pretrain.jsonl` | 續訓/continued pretraining（無指令可用） | `{"text", "source"}` | 21,604 | 156MB |

`alpaca_format.jsonl` 組成：RTL-Coder-27k 15,841 筆 + CodeV-All 163,125 筆。
`raw_code_pretrain.jsonl` 組成：CodeV-All 1,224 筆 + VeriGen-GitHub-Corpus 20,380 筆。

兩個檔案都是 JSONL（一行一筆 JSON），不是單一大 JSON array——如果你的訓練框架（如 LLaMA-Factory）預期的是一整包 JSON array 格式，需要再轉換一次，或確認你用的 `datasets.load_dataset("json", data_files=...)` 之類的載入方式本身就支援 JSONL（大部分現代框架都支援）。

## 檔案結構總覽

```
LoRA_train/
├── VALIDATION_REPORT.md          <- 本報告
├── merged_valid.jsonl            <- 4 個資料集去重合併後的語法驗證通過樣本（200,570 筆）
├── alpaca_format.jsonl           <- 訓練用：有 instruction 的樣本（178,966 筆）
├── raw_code_pretrain.jsonl       <- 訓練用：無 instruction，純程式碼（21,604 筆）
├── scripts/
│   ├── validate_and_build_jsonl.py   <- iverilog 語法驗證（WSL 執行）
│   ├── merge_valid.py                <- 跨資料集去重合併
│   ├── build_training_format.py      <- 轉成訓練格式
│   └── validation_summary.json       <- 各資料集驗證統計（機器可讀版）
├── RTL-Coder-27k/
│   ├── dataset/Resyn27k.json
│   ├── RTL-Coder-27k_valid.jsonl
│   └── RTL-Coder-27k_invalid.jsonl
├── RTL-Coder_small/
│   ├── RTL-Coder_small_valid.jsonl
│   └── RTL-Coder_small_invalid.jsonl
├── CodeV-All/
│   ├── codev-verilog.jsonl
│   ├── CodeV-All_valid.jsonl
│   └── CodeV-All_invalid.jsonl
├── VeriGen-GitHub-Corpus/
│   ├── Verilog_bigquery_GitHub.csv
│   ├── VeriGen-GitHub-Corpus_valid.jsonl
│   └── VeriGen-GitHub-Corpus_invalid.jsonl
└── MG-Verilog/
    └── mg_verilog_unvalidated.jsonl  <- 未驗證，未納入合併結果
```

## 已知限制 / 後續待辦

1. **只驗證了語法（`iverilog` 編譯），沒有跑 `vvp` 執行、也沒驗證功能正確性**——詳見上方「`iverilog` vs. `vvp`」段落。這批資料能編譯過，不代表邏輯是對的，也不保證實際執行不會 crash/hang。如果要更嚴謹，可以考慮兩步：(a) 先加一層 `vvp` smoke test 踢掉編譯過但執行會炸的樣本；(b) 對有 testbench 的子集（例如來自 TuRTLe benchmark 本身、但要注意資料洩漏問題）再做一層真正的功能驗證。
2. **VeriGen-GitHub-Corpus 的失敗率高（60%+）**，大多是缺少外部模組定義——如果想拉高這份資料的可用率，可以再寫一個「多檔案聯合編譯」的驗證版本（把同一個 repo 的多個檔案一起丟給 iverilog），但目前是逐檔案獨立驗證，還沒做這層。
3. **MG-Verilog 仍未使用**，如果之後想用它的多層次描述資料，需要額外設計「片段還原成完整模組」或「片段補全訓練」的驗證/訓練方式。
4. 兩個訓練格式檔案目前**沒有切 train/validation split**，正式訓練前需要自己切一份 held-out 驗證集。
