#------------------------------------------------------------------------------
# Synopsys Lint Run Script
#------------------------------------------------------------------------------

# Project inputs
set FILELIST   $::env(CSR_GEN_HOME)/RTL/filelist.f
set DEFINES    ""
set TOP_DESIGN m_vlsi_csr

# Lint setup
set enable_lint true
configure_lint_setup
configure_lint_tag_parameter \
  -tag W123 \
  -parameter HANDLE_LARGE_BUS \
  -value yes \
  -goal lint_rtl_enhanced

# Parse and elaborate
analyze \
  -format sverilog \
  -vcs "-f $FILELIST" \
  -define "$DEFINES -timescale=1ns/10ps +lint=TFIPC-L"
elaborate $TOP_DESIGN

# Run checks
check_lint
report_violations -app {lint} -verbose -include_compressed -limit 0 -file ./report_lint.full.log
report_violations -app {lint} -verbose -include_compressed -only_waived -limit 0 -file ./report_lint.waived.lo
# Open GUI
start_gui
