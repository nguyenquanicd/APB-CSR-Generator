#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CSR_GEN_HOME="$ROOT_DIR"

# The paths of filelist.f are relative to the folder of that file.
cd "$ROOT_DIR/RTL"

verilator --lint-only --sv -Wall \
  --top-module m_vlsi_csr \
  -f ${CSR_GEN_HOME}/RTL/filelist.f \
  "$@"
