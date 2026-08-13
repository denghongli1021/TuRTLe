# Export a merged (LoRA-merged) HF model to GGUF and register it as an Ollama model.
#
# Runs the conversion/quantization inside WSL (llama.cpp + its isolated venv,
# see TRAINING_GUIDE.md for why it's a separate venv from the training one),
# then runs `ollama create` on the Windows side, since the `ollama` CLI is
# only installed on Windows, not inside WSL.
#
# Usage (from PowerShell, repo root or anywhere):
#   .\LoRA_train\scripts\export_to_ollama.ps1 `
#       -MergedModelDir "LoRA_train\merged\qwen2.5-coder-7b-rtl" `
#       -OllamaModelName "qwen2.5-coder-7b-rtl" `
#       -QuantType "Q4_K_M"

param(
    [string]$MergedModelDir,
    [string]$MergedModelWslPath,
    [Parameter(Mandatory = $true)][string]$OllamaModelName,
    [string]$QuantType = "Q4_K_M"
)

$ErrorActionPreference = "Stop"

$RepoRoot = "C:\Users\dengh\Documents\code\TuRTLe"

function ToWslPath($winPath) {
    $p = $winPath -replace '\\', '/'
    $drive = $p.Substring(0, 1).ToLower()
    return "/mnt/$drive" + $p.Substring(2)
}

if ($MergedModelWslPath) {
    # Source lives natively inside WSL (e.g. the HF cache) -- use as-is, no
    # Windows<->WSL path translation, and skip the Test-Path check since this
    # side can't see into the WSL filesystem.
    $MergedModelWsl = $MergedModelWslPath
} elseif ($MergedModelDir) {
    $MergedModelAbs = Join-Path $RepoRoot $MergedModelDir
    if (-not (Test-Path $MergedModelAbs)) {
        throw "Merged model directory not found: $MergedModelAbs (run merge_lora.py first)"
    }
    $MergedModelWsl = ToWslPath $MergedModelAbs
} else {
    throw "Provide either -MergedModelDir (Windows path) or -MergedModelWslPath (path inside WSL, e.g. the HF cache)"
}
$GgufDir = Join-Path $RepoRoot "LoRA_train\gguf_export\$OllamaModelName"
New-Item -ItemType Directory -Force -Path $GgufDir | Out-Null
$GgufDirWsl = ToWslPath $GgufDir

$F16Gguf = "$GgufDirWsl/model-f16.gguf"
$QuantGguf = "$GgufDirWsl/model-$QuantType.gguf"
$QuantGgufWin = Join-Path $GgufDir "model-$QuantType.gguf"

Write-Host "==> [1/3] Converting HF model to GGUF (f16)..."
wsl.exe -e bash -lc "source ~/gguf_convert_venv/bin/activate && python3 ~/llama.cpp/convert_hf_to_gguf.py '$MergedModelWsl' --outfile '$F16Gguf' --outtype f16"
if ($LASTEXITCODE -ne 0) { throw "convert_hf_to_gguf.py failed" }

Write-Host "==> [2/3] Quantizing to $QuantType..."
wsl.exe -e bash -lc "~/llama.cpp/build/bin/llama-quantize '$F16Gguf' '$QuantGguf' $QuantType"
if ($LASTEXITCODE -ne 0) { throw "llama-quantize failed" }

# The f16 GGUF is a ~15GB intermediate that's never needed again once
# quantization succeeds -- this disk ran out of space twice from letting
# these pile up alongside the merged HF model, so clean up as we go now.
$F16GgufWin = Join-Path $GgufDir "model-f16.gguf"
Remove-Item -Path $F16GgufWin -Force -ErrorAction SilentlyContinue
Write-Host "(removed intermediate f16 GGUF to free disk space)"

Write-Host "==> [3/3] Registering with Ollama as '$OllamaModelName'..."
$SystemPrompt = "You are an expert Verilog/SystemVerilog RTL designer. Given a design specification, respond with only the complete Verilog module."
$ModelfilePath = Join-Path $GgufDir "Modelfile"
@"
FROM $QuantGgufWin
SYSTEM $SystemPrompt
"@ | Set-Content -Path $ModelfilePath -Encoding utf8

ollama create $OllamaModelName -f $ModelfilePath
if ($LASTEXITCODE -ne 0) { throw "ollama create failed" }

Write-Host ""
Write-Host "Done. Try it with:"
Write-Host "  ollama run $OllamaModelName"
Write-Host "Or use it in run_turtle.sh by passing '$OllamaModelName' as the model argument."
