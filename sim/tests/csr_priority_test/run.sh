#!/bin/bash
#--------------------------------------------------------------------
# Run the HW-priority tests on RTL freshly generated from a workbook.
#
# Usage: run.sh [-g <CSR_Generation.py>] [-v sync|async|both] [-k]
#   -g  generator to test (default: ../../../CSR_Generation.py). The generator copies
#       models/ from its own directory, so point it at a full checkout. To run the same
#       tests on an older version:
#         mkdir /tmp/old && git archive main | tar -x -C /tmp/old
#         run.sh -g /tmp/old/CSR_Generation.py
#   -v  variant to run (default: both)
#   -k  keep going to the next variant even if one fails (default behaviour)
# Build output goes to ./build/<variant>/ (git-ignored).
# Exit code: 0 if all selected variants pass, 1 otherwise.
#--------------------------------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$HERE/../../../CSR_Generation.py"
VARIANT=both
while getopts "g:v:k" opt; do
  case $opt in
    g) GEN="$(readlink -f "$OPTARG")" ;;
    v) VARIANT="$OPTARG" ;;
    k) ;;
    *) echo "usage: $0 [-g gen.py] [-v sync|async|both]"; exit 2 ;;
  esac
done

# Verilator from oss-cad-suite if it is not on PATH yet
command -v verilator >/dev/null 2>&1 || export PATH=/tools/OSS/oss-cad-suite/bin:$PATH
command -v verilator >/dev/null 2>&1 || { echo "verilator not found (module load oss-cad-suite)"; exit 2; }
# -s: skip user site-packages (a user-installed numpy 2.x breaks the system openpyxl)
PY="python3.9 -s"

BUILD="$HERE/build"
mkdir -p "$BUILD"
$PY "$HERE/make_workbook.py" "$BUILD/prio.xlsx" || exit 2

run_variant() {
  local name=$1 sheet=$2 dut=$3 defs=$4
  local dir="$BUILD/$name"
  rm -rf "$dir"; mkdir -p "$dir"
  ( cd "$dir" && $PY "$GEN" "$BUILD/prio.xlsx" "$sheet" > gen.log 2>&1 ) || { echo "[$name] generator failed, see $dir/gen.log"; return 1; }
  ( cd "$dir" && verilator --binary --sv --timing -Wno-fatal --top-module tb_csr \
      -DDUT_NAME=$dut $defs --Mdir obj -f RTL/filelist.f "$HERE/tb.sv" -o simv > build.log 2>&1 ) \
      || { echo "[$name] verilator build failed, see $dir/build.log"; return 1; }
  ( cd "$dir" && ./obj/simv > sim.log 2>&1 )
  local rc=$?
  grep -E 'FAIL|RESULT' "$dir/sim.log" | sed "s/^/[$name] /"
  return $rc
}

fail=0
if [ "$VARIANT" = both ] || [ "$VARIANT" = sync ];  then run_variant sync  SYNC_PRIO  m_csr_prio_sync  ""         || fail=1; fi
if [ "$VARIANT" = both ] || [ "$VARIANT" = async ]; then run_variant async ASYNC_PRIO m_csr_prio_async "-DASYNC"  || fail=1; fi
[ $fail -eq 0 ] && echo "OVERALL: PASS" || echo "OVERALL: FAIL"
exit $fail
