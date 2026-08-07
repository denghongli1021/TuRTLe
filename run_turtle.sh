#!/bin/bash

# 當任何指令發生錯誤時立即停止執行
set -e

# ==========================================
# ⚙️ Config 設定區 (預設為 true)
# ==========================================
# 是否生成原生詳細評測報告 (.json) (預設: "true")
GENERATE_DETAIL_REPORT=${GENERATE_DETAIL_REPORT:-"true"}

# ==========================================
# 📌 參數讀取 (帶有預設值)
# ==========================================
# 參數 1: 模式 (gen = 僅 API 生成, eval = 僅 Docker 評測, all = 一條龍跑完)
MODE=${1:-"all"}

# 參數 2: 測試任務 (預設: rtllm, 可選: verilog_eval_rtl | verilog_eval_cc | verigen | notsotiny)
TASK=${2:-"rtllm"}

# 參數 3: 模型名稱 (預設: qwen2.5-coder:7b)
MODEL=${3:-"qwen2.5-coder:7b"}

# 處理模型名稱中的特殊符號 (/ 與 :)，避免建立資料夾時失敗
SAFE_MODEL_NAME=$(echo "$MODEL" | tr '/:' '_')
OUTPUT_DIR="./results/${SAFE_MODEL_NAME}"/${TASK}/
JSONL_PATH="${OUTPUT_DIR}/${TASK}.jsonl"

# 輸出路徑設定
DETAIL_REPORT_PATH="${OUTPUT_DIR}/detail_report_${TASK}.json"
LOG_PATH="${OUTPUT_DIR}/eval_${TASK}.log"

# 設定 API Base URL (預設連線至本地 Ollama)
WIN_IP=$(ip route show | grep default | awk '{print $3}' 2>/dev/null || echo "localhost")
export TURTLE_BASE_URL=${TURTLE_BASE_URL:-"http://${WIN_IP}:11434/v1"}
export TURTLE_API_KEY=${TURTLE_API_KEY:-"ollama"}

# ==========================================
# 🚀 函式：API 代碼生成 (Generation)
# ==========================================
run_generation() {
    echo "=========================================="
    echo "🚀 [階段 1/2] 開始 API 代碼生成"
    echo "🔹 模式: $MODE | 任務: $TASK | 模型: $MODEL"
    echo "🔹 API: $TURTLE_BASE_URL"
    echo "=========================================="

    mkdir -p "$OUTPUT_DIR"

    uv run turtle/src/turtle.py --use-api \
        --model "$MODEL" \
        --task "$TASK" \
        --temperature 0.2 \
        --n_samples 1 \
        --save_generations \
        --save_generations_path "$JSONL_PATH" \
        --generation_only

    echo "✅ 生成完成！檔案已儲存至: $JSONL_PATH"
}

# ==========================================
# 🐳 函式：Docker EDA 評測 (Evaluation)
# ==========================================
run_evaluation() {
    echo "=========================================="
    echo "🐳 [階段 2/2] 開始 Docker EDA 工具評測"
    echo "🔹 任務: $TASK"
    echo "🔹 模型: $MODEL"
    echo "🔹 生成原生 Detail Report: $GENERATE_DETAIL_REPORT"
    echo "=========================================="

    if [ ! -f "$JSONL_PATH" ]; then
        echo "❌ 錯誤：找不到生成的檔案 $JSONL_PATH！"
        echo "💡 請先執行 gen 模式生成程式碼，或確認路徑是否正確。"
        exit 1
    fi

    # 確保 Docker 服務已啟動
    service docker status > /dev/null 2>&1 || service docker start

    # 處理布林旗標
    REPORT_FLAG="False"
    if [ "$GENERATE_DETAIL_REPORT" = "true" ] || [ "$GENERATE_DETAIL_REPORT" = "True" ] || [ "$GENERATE_DETAIL_REPORT" = "1" ]; then
        REPORT_FLAG="True"
    fi

    # 確保輸出目錄存在
    mkdir -p "$OUTPUT_DIR"

    echo "▶️ 開始執行評測並側錄 Console 輸出至: $LOG_PATH"

    # 執行 Docker 評測：
    # 1. 帶入 --metric_output_path 確保 turtle.py 原生 JSON 不會寫去 /tmp 後隨容器銷毀
    # 2. 透過 2>&1 | tee 側錄所有 Terminal 輸出
    docker run --rm -v $(pwd):/work -w /work ggcr0/turtle-eval:2.3.4 \
        python3 turtle/src/turtle.py \
        --task "$TASK" \
        --model "$MODEL" \
        --n_samples 1 \
        --load_generations_path "$JSONL_PATH" \
        --generate_report "$REPORT_FLAG" \
        --metric_output_path "$DETAIL_REPORT_PATH" 2>&1 | tee "$LOG_PATH"

    echo "=========================================="
    echo "✅ Docker 評測硬體模擬完成！"
    echo "📝 Terminal Log 紀錄點: $LOG_PATH"

    if [ "$REPORT_FLAG" = "True" ]; then
        echo "📊 原生 Detail Report 已儲存至: $DETAIL_REPORT_PATH"
    fi
    echo "=========================================="
}

# ==========================================
# 🔀 主流程控制
# ==========================================
case "$MODE" in
    gen)
        run_generation
        ;;
    eval)
        run_evaluation
        ;;
    all)
        run_generation
        echo ""
        run_evaluation
        ;;
    *)
        echo "❌ 未知的模式: $MODE"
        echo "----------------------------------------------------"
        echo "使用方式: ./run_gen.sh [模式] [任務] [模型]"
        echo "  - 模式: gen (僅API生成) | eval (僅Docker評測) | all (預設: 一條龍)"
        echo "  - 任務: rtllm | verilog_eval_rtl | notsotiny ... (預設: rtllm)"
        echo "  - 模型: qwen2.5-coder:7b | mistralai/codestral-2508 ... (預設: qwen2.5-coder:7b)"
        echo "----------------------------------------------------"
        exit 1
        ;;
esac