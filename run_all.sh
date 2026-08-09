#!/bin/bash

# ==========================================
# ⚙️ 設定區 Config
# ==========================================
# 1. 全部可用的 Task 清單 (預設值，沒指定要跑哪些 task 時就跑全部)
ALL_TASKS="rtllm,notsotiny,verilog_eval_rtl,verilog_eval_cc,verigen"

# 2. 預設模型 (若執行時沒帶參數則使用此預設值)
DEFAULT_MODEL="qwen2.5-coder:7b"
MODEL=${1:-"$DEFAULT_MODEL"}

# 3. 執行模式 (預設為 "all" 一條龍：API 生成 + Docker 評測)
MODE=${2:-"all"}

# 4. 要執行的 Task 任務清單，逗號分隔
#    優先順序: 第 3 個參數 > TASKS 環境變數 > 預設全部
#    例如: ./run_all.sh qwen2.5-coder:7b all "rtllm,verigen"
#      或: TASKS="rtllm,verigen" ./run_all.sh
TASK_SELECTION=${3:-${TASKS:-$ALL_TASKS}}
IFS=',' read -ra TASKS <<< "$TASK_SELECTION"
# 去除每個項目前後可能的空白
for i in "${!TASKS[@]}"; do
    TASKS[$i]=$(echo "${TASKS[$i]}" | xargs)
done

# ==========================================
# 🚀 執行主流程
# ==========================================
echo "===================================================="
echo "🎯 開始執行批次自動評測流程 (Run All Tasks)"
echo "🔹 目標模型: $MODEL"
echo "🔹 執行模式: $MODE"
echo "🔹 包含任務: ${TASKS[*]}"
echo "===================================================="
echo ""

# 檢查底層的 run_turtle.sh 是否存在
if [ ! -f "./run_turtle.sh" ]; then
    echo "❌ 錯誤：找不到 ./run_turtle.sh 腳本，請確認兩者位在同一目錄下！"
    exit 1
fi

# 確保 run_turtle.sh 有可執行權限
chmod +x ./run_turtle.sh

# 計數器與紀錄陣列
TOTAL_TASKS=${#TASKS[@]}
CURRENT_INDEX=1
FAILED_TASKS=()

# 開始遍歷每一個 Task
for TASK in "${TASKS[@]}"; do
    echo "----------------------------------------------------"
    echo "▶️ [$CURRENT_INDEX/$TOTAL_TASKS] 正在執行任務: Task = $TASK | Model = $MODEL"
    echo "----------------------------------------------------"

    # 呼叫 run_turtle.sh 執行單一任務，即使其中一個失敗也不中斷整個流程
    if ./run_turtle.sh "$MODE" "$TASK" "$MODEL"; then
        echo "✅ [$CURRENT_INDEX/$TOTAL_TASKS] 任務 [$TASK] 順利完成！"
    else
        echo "⚠️ [$CURRENT_INDEX/$TOTAL_TASKS] 任務 [$TASK] 執行過程中發生錯誤！"
        FAILED_TASKS+=("$TASK")
    fi

    echo ""
    CURRENT_INDEX=$((CURRENT_INDEX + 1))
done

# ==========================================
# 📊 最終執行結果統計
# ==========================================
echo "===================================================="
echo "🎉 所有 Task 任務評測流程已結束！"
echo "🔹 模型: $MODEL"
echo "🔹 成功任務數: $((TOTAL_TASKS - ${#FAILED_TASKS[@]})) / $TOTAL_TASKS"

if [ ${#FAILED_TASKS[@]} -ne 0 ]; then
    echo "❌ 執行失敗的任務: ${FAILED_TASKS[*]}"
else
    echo "🌟 所有任務皆已成功跑完！"
fi

SAFE_MODEL_NAME=$(echo "$MODEL" | tr '/:' '_')
echo "📁 所有產出結果檔已儲存於: ./results/${SAFE_MODEL_NAME}/"
echo "===================================================="