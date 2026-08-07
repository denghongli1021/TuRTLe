# chmod +x run_gen.sh
# ./run_gen.sh

#!/bin/bash

# 當任何指令發生錯誤時立即停止執行
set -e

# ==========================================
# 參數讀取 (帶有預設值)
# ==========================================
# 參數 1: 模式 (gen = 僅生成, eval = 僅Docker評測, all = 一條龍跑完)
MODE=${1:-"all"}

# 參數 2: 測試任務 (預設: rtllm)
TASK=${2:-"rtllm"}

# 參數 3: 模型名稱 (預設: qwen2.5-coder:7b)
MODEL=${3:-"qwen2.5-coder:7b"}

# 處理模型名稱中的特殊符號 (/ 與 :)，避免建立資料夾時出錯
SAFE_MODEL_NAME=$(echo "$MODEL" | tr '/:' '_')
OUTPUT_DIR="./results/${SAFE_MODEL_NAME}"
JSONL_PATH="${OUTPUT_DIR}/${TASK}.jsonl"

# 設定 API (若環境變數沒設定則使用本地 Ollama 預設值)
WIN_IP=$(ip route show | grep default | awk '{print $3}')

export TURTLE_BASE_URL="http://${WIN_IP}:11434/v1"
export TURTLE_API_KEY="ollama"

# ==========================================
# 函式：API 代碼生成 (Generation)
# ==========================================
run_generation() {
    echo "=========================================="
    echo "🚀 [階段 1/2] 開始 API 代碼生成"
    echo "🔹 模式: $MODE"
    echo "🔹 任務: $TASK"
    echo "🔹 模型: $MODEL"
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
# 函式：Docker EDA 評測 (Evaluation)
# ==========================================
run_evaluation() {
    echo "=========================================="
    echo "🐳 [階段 2/2] 開始 Docker EDA 工具評測"
    echo "🔹 任務: $TASK"
    echo "🔹 讀取檔案: $JSONL_PATH"
    echo "=========================================="

    # 檢查 jsonl 檔案是否存在
    if [ ! -f "$JSONL_PATH" ]; then
        echo "❌ 錯誤：找不到生成的檔案 $JSONL_PATH！"
        echo "💡 請先執行 gen 模式生成程式碼，或確認路徑是否正確。"
        exit 1
    fi

    # 確保 Docker 服務已有啟動
    service docker status > /dev/null 2>&1 || service docker start

    docker run --rm -v $(pwd):/work -w /work ggcr0/turtle-eval:2.3.4 \
        python3 turtle/src/turtle.py \
        --task "$TASK" \
        --model "$MODEL" \
        --n_samples 1 \
        --load_generations_path "$JSONL_PATH"

    echo "✅ Docker 評測完成！"
}

# ==========================================
# 主流程控制 (根據 MODE 執行)
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
        echo "使用方式: ./run_turtle.sh [模式] [任務] [模型]"
        echo "  - 模式: gen (僅API生成) | eval (僅Docker評測) | all (生成+評測)"
        echo "  - 任務: rtllm | verilog_eval_rtl | notsotiny ... (預設: rtllm)"
        echo "  - 模型: qwen2.5-coder:7b | gpt-4o-mini ... (預設: qwen2.5-coder:7b)"
        echo "----------------------------------------------------"
        exit 1
        ;;
esac