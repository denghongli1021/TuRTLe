# TuRTLe 常用指令

## 0. Ollama 環境設定（WSL 連不到 Windows 端 Ollama 時）

```powershell
# 1. 先關閉背景進程
taskkill /f /im "ollama app.exe"
taskkill /f /im "ollama.exe"

# 2. 設定永久環境變數（讓 Ollama 監聽 0.0.0.0，WSL 才連得到）
setx OLLAMA_HOST "0.0.0.0"
setx OLLAMA_ORIGINS "*"
setx OLLAMA_KEEP_ALIVE "24h"
setx OLLAMA_NUM_PARALLEL "1"

# 3. 重新開啟 Ollama app，讓它套用新設定
```

驗證有沒有生效（要看到 `0.0.0.0:11434`，不是只有 `127.0.0.1:11434`）：

```powershell
netstat -ano | findstr 11434
```

WSL 這邊測試連線：

```bash
curl http://172.26.16.1:11434/api/tags
```

---

## 1. 跑單一任務（`run_turtle.sh`）

```bash
./run_turtle.sh [模式] [任務] [模型]
```

| 參數 | 可選值 | 預設 |
|---|---|---|
| 模式 | `gen`（只生成）\| `eval`（只評測）\| `all`（一條龍） | `all` |
| 任務 | `rtllm` \| `verilog_eval_rtl` \| `verilog_eval_cc` \| `verigen` \| `notsotiny` | `rtllm` |
| 模型 | 見下方「可用模型」 | `qwen2.5-coder:7b` |

範例：

```bash
./run_turtle.sh all rtllm qwen2.5-coder:7b
./run_turtle.sh all rtllm rtlcoder-deepseek-v1.1:q5_k_m
```

---

## 2. 跑多個任務（`run_all.sh`）

```bash
./run_all.sh [模型] [模式] [任務清單，逗號分隔]
```

不帶第 3 個參數 = 跑全部 5 個任務。

```bash
# 全部任務
./run_all.sh qwen2.5-coder:7b all

# 跳過 notsotiny，只跑其他 4 個
./run_all.sh qwen2.5-coder:7b all "rtllm,verilog_eval_rtl,verilog_eval_cc,verigen"

# 也可以用環境變數指定（不用每次打落落長的參數）
export TASKS="rtllm,verilog_eval_rtl,verilog_eval_cc,verigen"
./run_all.sh qwen2.5-coder:7b all
```

---

## 3. 可用模型（`ollama list`）

| 模型名稱 | 大小 | 備註 |
|---|---|---|
| `qwen2.5-coder:7b` | 4.7 GB | 本地跑，Q4_K_M 量化 |
| `rtlcoder-deepseek-v1.1:f16` | 13 GB | 原始精度，未量化，8GB VRAM 顯卡容易溢出到系統記憶體、跑很慢 |
| `rtlcoder-deepseek-v1.1:q6_k` | 5.5 GB | 接近 F16 品質 |
| `rtlcoder-deepseek-v1.1:q5_k_m` | 4.8 GB | 跟 8GB VRAM 較貼合，速度較快 |

---

## 4. 已知問題：notsotiny 部分題目 context 超過 4096

RTLCoder 系列模型建立時沒有設定 `num_ctx`，Ollama 預設只有 4096 tokens，
notsotiny 有些題目的 prompt 會超過（實測遇過 5874 tokens），導致該題重試 4 次後被記為
`malformed generation`（不會中斷整個流程，只是那幾題會失敗）。

要修正，幫模型加大 context window（會增加 VRAM 用量，量化版本比較撐得住）：

```bash
cat > Modelfile <<'EOF'
FROM rtlcoder-deepseek-v1.1:q5_k_m
PARAMETER stop "<|EOT|>"
PARAMETER num_ctx 8192
EOF

ollama create rtlcoder-deepseek-v1.1:q5_k_m -f Modelfile
```

同樣的方法套用到 `q6_k` 或 `f16`，把 `FROM` 那行的模型名稱換掉即可。
