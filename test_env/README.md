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
