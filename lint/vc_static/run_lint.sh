#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="lint_run_$(date +%Y%m%d_%H%M%S).log"

echo "Starting Lint run. Logging to: $LOG_FILE"
vc_static_shell -f run_lint.tcl 2>&1 | tee "$LOG_FILE"
echo "Lint run completed. Log saved to: $LOG_FILE"
