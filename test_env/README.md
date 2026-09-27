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
