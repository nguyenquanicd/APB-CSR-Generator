# Test Environment Setup

This directory contains the lint and simulation environment for the CSR Generator project.

## Directory Structure

```
csr_generator/
├── lint/
│   └── verilator/
│       └── run_lint.sh    # Lint script using Verilator
├── sim/
│   ├── lib/
│   │   └── apb_slave_bfm.sv   # APB slave BFM library
│   ├── tests/
│   │   └── csr_test/
│   │       └── tb.sv          # Testbench for m_vlsi_csr
│   └── verilator/
│       └── Makefile           # Simulation Makefile
└── RTL/
    └── filelist.f             # RTL source file list
```

## Setup

Set the environment variable before running lint or simulation:

```bash
export CSR_GEN_HOME=/home/ltthinh/csr_generator
```

## Lint

Run lint check using Verilator:

```bash
# From project root
./lint/verilator/run_lint.sh

# Or from sim/verilator directory
make lint
```

## Simulation

Run simulation using Verilator:

```bash
cd sim/verilator
make simv    # Build simulator
make run     # Run simulation
make clean   # Clean build artifacts
```

## Waveform Viewing

After simulation, a VCD file (`tb_csr.vcd`) will be generated in the `sim/verilator` directory.
View it using GTKWave:

```bash
gtkwave tb_csr.vcd
```

## Test Description

The testbench (`sim/tests/csr_test/tb.sv`) includes the following tests:

1. Write to ABC register
2. Read back ABC register
3. Write to DEF register
4. Read back DEF register
5. HW write to abc_start2
6. HW write to abc_start4
7. HW write to def_start1
8. Read-only input def_start3
9. Address error test (misaligned address)
10. Protection error test

## Async (CDC) Testbench

`sim/tests/csr_test/tb2.sv` runs the same scenario against the async DUT (`i_bus_clk`/`i_reg_clk`
as separate clocks) plus:

11. HWI test - APB write-0 should not clear a HW-set bit
12. W1C test - multiple bits selective clear
13. CDC data-integrity stress test - back-to-back write/read bursts verifying `o_prdata` always
    reflects the last write as soon as `o_pready` asserts (regression for the `reg_prdata`/
    `reg_prdata_bus` cross-domain resync fix in `CSR_Generation.py`)

Run it with:

```bash
cd sim/verilator
make -f Makefile_async run
```

`sim/tests/csr_cdc_test/tb2.sv` is the same test sequence but with `i_reg_clk` deliberately set
faster than `i_bus_clk` (3ns vs 10ns) — the ratio needed to actually expose a missed/stale
`o_prdata` capture across the clock domain crossing (with the default 10ns/15ns ratio, the enable
pulse is always wider than one `i_bus_clk` period and the bug can't be observed in zero-delay
simulation). Run it with:

```bash
cd sim/verilator
TEST=csr_cdc_test make -f Makefile_async run
```

## HW-vs-SW Priority Test

`sim/tests/csr_priority_test/` checks that a HW write beats a same-cycle SW write on `rwi` and `w1c`
fields, and that a SW write to one field never discards a HW event or a SW write on another field of
the same register. Unlike the tests above it generates its own DUT from a workbook built by
`make_workbook.py` (sync and async variants, so it also tests the generator), and aligns the HW event
with the SW commit using `dut.we_sts`, which makes the collision exact for any clock ratio.

```bash
sim/tests/csr_priority_test/run.sh                 # generate, build and run sync + async
sim/tests/csr_priority_test/run.sh -v async        # one variant
sim/tests/csr_priority_test/run.sh -g <old-checkout>/CSR_Generation.py   # run against another generator
```

Tests T06-T14 fail on a generator where SW wins (e.g. `main` before this change); T01-T05 and
T15-T18 (no collision, other register, or HW event one cycle after the SW commit) pass on both.
Python is run with `python3.9 -s` because a user-site numpy 2.x breaks the system `openpyxl`.
