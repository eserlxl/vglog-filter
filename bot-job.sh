#!/bin/bash
# bot-job.sh — Send a random prompt from prompts/ to Gemini CLI
# Author: lxl-dev-bot 🤖
# License: GPL-3.0-or-later

set -Eeuo pipefail
IFS=$'\n\t'

MODEL="${1:-gemini-2.5-flash}"
PROMPT_DIR="bot/prompts"
LOG_DIR="bot/logs"
API_KEY="${GEMINI_API_KEY:-}"

# Colors for output
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# --- checks ---
if ! command -v gemini >/dev/null 2>&1; then
    echo -e "${YELLOW}Error:${RESET} gemini CLI not found in PATH" >&2
    exit 1
fi

if [[ -z "$API_KEY" ]]; then
    echo -e "${YELLOW}Error:${RESET} GEMINI_API_KEY environment variable not set" >&2
    exit 1
fi

if [[ ! -d "$PROMPT_DIR" ]]; then
    echo -e "${YELLOW}Error:${RESET} prompts folder not found at $PROMPT_DIR" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

# --- select random prompt file ---
if command -v shuf >/dev/null 2>&1; then
    PROMPT_FILE=$(find "$PROMPT_DIR" -type f -name '*.txt' | shuf -n 1 2>/dev/null || true)
else
    PROMPT_FILE=$(find "$PROMPT_DIR" -type f -name '*.txt' | sort -R | head -n 1 2>/dev/null || true)
fi

if [[ -z "$PROMPT_FILE" ]]; then
    echo -e "${YELLOW}Error:${RESET} No prompt files found in $PROMPT_DIR" >&2
    exit 1
fi

echo -e "[🤖] Selected prompt: ${BOLD}$PROMPT_FILE${RESET}"

# --- read prompt text ---
PROMPT_TEXT=$(<"$PROMPT_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
    echo -e "${YELLOW}Error:${RESET} Prompt file is empty: $PROMPT_FILE" >&2
    exit 1
fi

# --- run Gemini ---
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/output_$TIMESTAMP.log"

{
    echo "=================================================="
    echo "Prompt file: $PROMPT_FILE"
    echo "Prompt text:"
    echo "$PROMPT_TEXT"
    echo "=================================================="
    echo
    echo "[Gemini Output]"
    echo
} >> "$LOG_FILE"

echo -e "[🤖] Sending to Gemini model: ${BOLD}$MODEL${RESET}"
gemini --model "$MODEL" --yolo -p "$PROMPT_TEXT" | tee -a "$LOG_FILE"

echo -e "[${GREEN}✓${RESET}] Done. Output saved to: ${BOLD}$LOG_FILE${RESET}"
