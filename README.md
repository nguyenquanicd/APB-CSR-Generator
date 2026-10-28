# APB CSR Generation Tool

## Overview

This document describes the **APB-CSR-Generator**, a Python tool that reads a register-map
specification from an Excel workbook and emits a synthesizable SystemVerilog **APB4 slave** module
exposing those registers — address decode, `SLVERR`/`PREADY` handshaking, per-bit read/write/insert/
clear semantics, and (optionally) a full clock-domain-crossing bridge between the APB bus clock and an
independent register clock — with no hand-written RTL required for a new CSR block.

Given a workbook such as `CSR_Example.xlsx`, running the tool produces one `.sv` module, a matching
`filelist.f`, a copy of the CDC synchronizer template it depends on, and a JSON dump of the parsed
configuration for review — see [Generation Workflow](#generation-workflow).

---

## Features

| Feature | Description |
|---------|-------------|
| **Bus Protocol** | APB4 slave (`PSEL`/`PENABLE`/`PREADY`/`PSLVERR`, 2-phase SETUP/ACCESS) |
| **Register Fields** | `rw` (read/write), `ro` (read-only, HW-driven), `rwi` (read/write/insert — SW or HW can update), `w1c` (write-1-to-clear) |
| **Bit-level granularity** | Each register is built from independently-typed bit/field slices — a single 32-bit register can mix `rw`, `ro`, `rwi`, and `w1c` fields |
| **Clock domains** | Single-clock (`Asynchronous=0`, everything on `i_bus_clk`) or dual-clock (`Asynchronous=1`, registers live on an independent `i_reg_clk`, bridged by a 2-flop req/ack handshake) — see [Architecture](#architecture) |
| **Protection / error checking** | Optional `PPROT`-based access protection (`i_protect_en`) and `SLVERR` generation on protection failure, misaligned address, or partial `PSTRB` on a write (`i_slverr_en`) |
| **Address decode** | Auto-generated per register from its workbook-assigned offset (`PARA_<REG>_OFFSET` localparams) |
| **Input** | A single Excel workbook (`openpyxl`), one sheet per register map |
| **Output** | One `.sv` module + `filelist.f` + CDC synchronizer template + a JSON debug dump of the parsed config |

---

## Interface Signals

### APB Bus Interface (always present)

| Signal | Direction | Description |
|--------|-----------|--------------|
| `i_bus_clk` | Input | APB bus clock |
| `i_bus_rstn` | Input | APB bus reset, active low |
| `i_psel` | Input | Peripheral select |
| `i_penable` | Input | Enable — low during SETUP, high during ACCESS |
| `i_paddr` | Input | Address (`PARA_ADDR_WD` bits, workbook `Address Width`) |
| `i_pwrite` | Input | 1 = write, 0 = read |
| `i_pwdata` | Input | Write data (`PARA_DATA_WD` bits, workbook `Data Width`) |
| `i_pstrb` | Input | Byte strobes (4 bits) — a write with any strobe bit low is flagged `SLVERR` when `i_slverr_en=1` |
| `i_pprot` | Input | Protection attributes (3 bits, APB4 `PPROT`) |
| `i_protect_en` | Input | 1 = gate `PPROT[1]` (secure/non-secure) into the `SLVERR` check; 0 = protection check disabled |
| `i_slverr_en` | Input | 1 = enable `SLVERR` generation (protection/alignment/strobe checks); 0 = always respond `OKAY` |
| `o_pready` | Output | Transfer ready |
| `o_pslverr` | Output | Slave error response |
| `o_prdata` | Output | Read data (`PARA_DATA_WD` bits) |

### Register Clock Interface (only when `Asynchronous=1`)

| Signal | Direction | Description |
|--------|-----------|--------------|
| `i_reg_clk` | Input | Independent register-bank clock |
| `i_reg_rstn` | Input | Register-bank reset, active low |

### Per-Register, Per-Bit Ports (generated per field, named `<reg>_<bit>`)

| Field Type | Generated Ports |
|------------|------------------|
| `ro` | `i_<reg>_<bit>` (input) — the register value is a direct passthrough of this port, no flop |
| `rw` | `o_<reg>_<bit>` (output) — SW-writable, reads back the last SW write |
| `rwi` | `o_<reg>_<bit>` (output), `i_hw_wdata_<reg>_<bit>` (input), `i_hw_we_<reg>_<bit>` (input, 1 bit) — HW write takes priority over a same-cycle SW write |
| `w1c` | `o_<reg>_<bit>` (output), `i_hw_wdata_<reg>_<bit>` (input), `i_hw_we_<reg>_<bit>` (input, 1 bit) — a SW write of `1` clears the bit; HW can independently set it via `i_hw_we_*`/`i_hw_wdata_*`, and a same-cycle HW event wins over the SW clear |

A field named `reserved` gets no ports at all — it reads back as `0` and ignores writes.

---

## Architecture

**[Open the interactive architecture diagram](docs/architecture.html)** — a self-contained,
colorful HTML page (no build step, no CDN) covering the generated module's block-level dataflow: APB
decode/capture, the CDC handshake bridge, the per-register banks, and the `PRDATA` mux/resync path.
Blocks are colored by clock domain (`i_bus_clk` / bridges both / `i_reg_clk`) rather than by role, since
this project's whole reason to have an async option is the domain crossing.

The **generation pipeline** itself — workbook in, RTL out — is a straight-line script, not a
hardware dataflow, so it's shown here as a flowchart rather than in the interactive page:

```mermaid
flowchart LR
    WB["Workbook .xlsx\n(Table - Configuration +\nTable - REGISTER)"] --> PARSE["CSR_Generation.py\nopenpyxl row scanner"]
    PARSE --> CFG["module_name, addr_wd,\ndata_wd, protocol,\nasync_option"]
    PARSE --> REGS["reg_list[]\none `register` per row-group,\neach holding `bit[]`"]
    CFG --> SFR["sfr\n(top-level assembler)"]
    REGS --> SFR
    SFR --> PROTO["apb_protocol\nSETUP/ACCESS, SLVERR,\nPREADY, optional CDC bridge"]
    SFR --> REGRTL["register / bit\nper-field port + FF + mux RTL"]
    PROTO --> GENRTL["sfr.gen_rtl()"]
    REGRTL --> GENRTL
    GENRTL --> SV["RTL/(module_name).sv"]
    GENRTL --> FL["RTL/filelist.f"]
    PARSE -.copies.-> SYNC["RTL/models/m_vlsi_synch.sv"]
    SFR --> JSON["sfr.gen_json()"]
    JSON --> DBG["Debug/debug.json"]
```

| Python Class | Purpose |
|---------------|---------|
| `port` | One RTL port/logic declaration (name, direction, width) — renders its own `input`/`output`/`logic` line |
| `bit` | One register field: name, bit range (`field`), type (`rw`/`ro`/`rwi`/`w1c`), reset value, clock (`i_bus_clk` or `i_reg_clk` depending on `Asynchronous`). Generates its own next-value mux and flop. |
| `register` | One 32-bit register: owns a list of `bit`s, generates the register's `we_<reg>` write-enable, the address-offset `localparam`, and the `always_comb` that packs all its fields into `<reg>_value` |
| `apb_protocol` | The bus-facing half: SETUP/ACCESS decode, `SLVERR` checks, address/write-data capture, and — only when `Asynchronous=1` — the full `i_bus_clk` ↔ `i_reg_clk` handshake bridge (see [CDC Handshake](#clock-domain-crossing-asynchronous1-only)) |
| `sfr` | Top-level assembler: combines `apb_protocol` + every `register` into one module, and can emit RTL (`gen_rtl`), a debug JSON (`gen_json`), or a standalone testbench stub (`gen_tb`, unused by the current CLI flow) |

---

## Design Description

### 1. APB Handshake (SETUP / ACCESS)

Every transfer is decoded off `i_psel`/`i_penable` alone — `apb_setup = i_psel & ~i_penable` fires for
exactly one cycle per transfer (the APB SETUP phase), and that single-cycle pulse is what captures
`i_paddr`/`i_pwdata` and evaluates the `SLVERR` conditions below. `PREADY` is asserted the following
cycle (ACCESS phase), once the transfer either completes or is immediately flagged as an error.

```mermaid
sequenceDiagram
    participant M as APB Master
    participant P as apb_protocol
    participant R as register bank

    M->>P: PSEL=1, PENABLE=0 (SETUP), paddr/pwrite/pwdata/pstrb/pprot
    P->>P: apb_setup, apb_protect, apb_slverr (combinational)
    P->>P: capture reg_address, reg_pwdata; latch reg_slverr
    M->>P: PENABLE=1 (ACCESS)
    alt apb_slverr was set
        P-->>M: PREADY=1, PSLVERR=1 (next cycle)
    else write, no error
        P->>R: we_reg (address-matched write enable)
        R->>R: nxt_reg_bit per field type, flop on clk edge
        P-->>M: PREADY=1, PSLVERR=0
    else read, no error
        R->>P: reg_value muxed onto nxt_prdata by reg_address
        P-->>M: PREADY=1, PRDATA=reg_prdata, PSLVERR=0
    end
```

`SLVERR` (when `i_slverr_en=1`) is asserted on any of:
- `i_protect_en=1` and `i_pprot[1]` indicates non-secure access, or
- `i_paddr[1:0] != 0` (misaligned word address), or
- a write (`i_pwrite=1`) with `i_pstrb != 4'b1111` (a partial-strobe write — this generator's templates
  reject any write that doesn't touch all 4 byte lanes, rather than silently masking to the strobed
  bytes).

### 2. Field Types

| Type | SW read | SW write | HW input | Next-value priority |
|------|---------|----------|----------|----------------------|
| `ro` | Yes (passthrough) | Ignored | `i_<reg>_<bit>` | N/A — no register, wired straight through |
| `rw` | Yes | Yes | — | SW write wins, else holds |
| `rwi` | Yes | Yes | `i_hw_we_*` / `i_hw_wdata_*` | **HW write > SW write > hold** |
| `w1c` | Yes | Writing `1` clears the bit, `0` is a no-op | `i_hw_we_*` / `i_hw_wdata_*` (typically HW *sets* the bit) | **HW write (set) > SW write (clear) > hold** |

```mermaid
flowchart TD
    HWCHK{"i_hw_we_reg_bit?\n(rwi / w1c only)"}
    HWCHK -->|"yes"| HWVAL["nxt = i_hw_wdata_reg_bit"]
    HWCHK -->|"no"| WE{"we_reg\n(address match AND\nwrite-enable)?"}
    WE -->|"yes, type=rw"| SWVAL["nxt = pwdata field"]
    WE -->|"yes, type=rwi"| SWVAL
    WE -->|"yes, type=w1c"| CLR["nxt = reg AND NOT(pwdata field)\n(1 clears, 0 holds)"]
    WE -->|"no"| HOLD["nxt = reg (unchanged)"]
```

The priority is decided **per field**, not per register. `we_reg` is shared by every field of a register,
but a HW event on one field only overrides that field: a SW write to the register still lands on all its
other fields, and a SW write never discards a HW event on a field it does not clear. Consequences:

- `w1c`: an event arriving in the same cycle as a SW clear of the same bit is kept (the bit stays `1`), so
  SW sees it on the next read. This also holds when SW writes any other field of the same register.
- `rwi`: a SW write to a field is overridden by a same-cycle HW write to that same field. Used as a
  request/acknowledge handshake (SW sets, HW clears), SW should only write when no request is pending;
  a write that lands on the same edge as the acknowledge is dropped.
- A field wider than one bit is replaced as a whole by `i_hw_wdata_*` when `i_hw_we_*` is set; HW cannot
  update only some bits of a multi-bit `rwi`/`w1c` field.

### 3. Clock-Domain Crossing (`Asynchronous=1` only)

When the workbook's `Asynchronous` cell is `1`, every register field flops on `i_reg_clk` instead of
`i_bus_clk`, and `apb_protocol` inserts a 2-flop req/ack toggle bridge (`m_vlsi_synch`, `PARA_LEVELS=2`)
each direction so a single APB transfer's write-enable / read-enable pulse — and the eventual `PRDATA`
value — cross safely between the two clocks:

1. `apb_read`/`apb_write` (one-cycle pulses in `i_bus_clk`) toggle a request flip-flop.
2. That toggle is synchronized into `i_reg_clk` through a 2-flop synchronizer; an edge there produces
   `apb_read_en`/`apb_write_en` — the actual field write-enables and `PRDATA`-latch enable, entirely in
   the `i_reg_clk` domain.
3. The register bank's ack toggles back, is synchronized back into `i_bus_clk`, and a falling-edge
   pulse on that resynchronized signal drives `PREADY`.
4. `PRDATA` itself is **not** passed through a bit synchronizer — since it only changes once per
   completed read and is already quasi-static by the time the bus-clock ack pulse arrives, it's simply
   re-registered in `i_bus_clk` on that same already-synchronized pulse (the fix documented in
   [Revision 1.1](#revision-history)).

At `Asynchronous=0`, none of this exists — `apb_read_en`/`apb_write_en` are just one-cycle-delayed
versions of `apb_read`/`apb_write` on `i_bus_clk`, and `PRDATA` is registered directly.

---

## Register Map

The tool ships one worked example, `CSR_Example.xlsx` (`Asynchronous=1`, `Address Width=16`,
`Data Width=32`, module name `m_vlsi_csr`), defining two registers:

### `abc` — offset `0x0000`

```mermaid
packet-beta
0-24: "reserved (ro)"
25-26: "start4 (rwi)"
27-28: "start3 (rw)"
29: "start2 (rwi)"
30: "start1 (rw)"
31: "start0 (ro)"
```

| Bits | Field | Type | Reset | Description |
|------|-------|------|-------|--------------|
| `[31]` | `start0` | `ro` | `0x0` | External status bit, driven by `i_abc_start0` |
| `[30]` | `start1` | `rw` | `0x0` | Software start control bit 1 |
| `[29]` | `start2` | `rwi` | `0x0` | Software/hardware start control bit 2 |
| `[28:27]` | `start3` | `rw` | `0x0` | Software start control field 3 |
| `[26:25]` | `start4` | `rwi` | `0x0` | Software/hardware start control field 4 |
| `[24:0]` | `reserved` | `ro` | `0x0` | Reserved — read-as-zero, write ignored |

### `def` — offset `0x0004`

```mermaid
packet-beta
0-24: "reserved (ro)"
25-26: "start4 (rwi)"
27-28: "start3 (w1c)"
29: "start2 (w1c)"
30: "start1 (rwi)"
31: "start0 (rw)"
```

| Bits | Field | Type | Reset | Description |
|------|-------|------|-------|--------------|
| `[31]` | `start0` | `rw` | `0x0` | Software start control bit 0 |
| `[30]` | `start1` | `rwi` | `0x0` | Software/hardware start control bit 1 |
| `[29]` | `start2` | `w1c` | `0x0` | Write-1-to-clear status bit 2 |
| `[28:27]` | `start3` | `w1c` | `0x0` | Write-1-to-clear status field 3 |
| `[26:25]` | `start4` | `rwi` | `0x0` | Software/hardware start control field 4 |
| `[24:0]` | `reserved` | `ro` | `0x0` | Reserved — read-as-zero, write ignored |

`def` deliberately exercises every field type (`rw`, `rwi`, `w1c`, `ro`) in one register, on top of
`abc` covering `rw`/`rwi`/`ro` — between the two, the example demonstrates all four.

---

## Generation Workflow

### Workbook Format

Each sheet has two blocks, read top-to-bottom by row (see `CSR_FORMAT_PROPOSAL.xlsx` for the blank
template):

1. **`Table - Configuration`** — key/value rows: `Module Name`, `Protocol` (currently only `apb` is
   implemented), `Data Width`, `Address Width`, `Asynchronous` (`0`/`1`).
2. **`REGISTER`** section — one row starts a new register (`Register Name`, `Offset`, `Reset Value`,
   `Description` populated); its bit rows follow directly beneath with only the bit columns
   (`Bit Name`, `Bit Field` e.g. `[31]`/`[28:27]`, `Bit Type`, `Reset Value`, `Description`) filled in,
   until the next row with a register name starts the next register.

### Running the Generator

```bash
python3.9 CSR_Generation.py <workbook.xlsx> <sheet_name>
# example:
python3.9 CSR_Generation.py CSR_Example.xlsx CSR
```

Requires `openpyxl` (plus the standard-library `getpass`/`datetime`/`os`/`shutil`).

### Output Layout

```
<cwd>/
├── RTL/
│   ├── <module_name>.sv       # the generated CSR module
│   ├── filelist.f              # points at the .sv above + models/m_vlsi_synch.sv
│   └── models/
│       └── m_vlsi_synch.sv     # CDC synchronizer template — copied in, not generated;
│                                # replace with your own verified sync cell before tapeout
└── Debug/
    └── debug.json               # parsed configuration, for reviewing what was actually read
                                  # from the workbook before trusting the generated RTL
```

`filelist.f` and `Debug/debug.json` are overwritten on every run; `RTL/models/m_vlsi_synch.sv` is only
copied in if it doesn't already exist there (so a manually-replaced synchronizer isn't clobbered on
re-generation — see `CSR_Generation.py`'s `shutil.copyfile` vs `copytree` branch).

---

## Constraints and Limitations

| Constraint | Description |
|------------|--------------|
| **Full-strobe writes only** | A write with any `i_pstrb` bit low is flagged `SLVERR` (when `i_slverr_en=1`) rather than performing a byte-masked write — there is no partial-write support |
| **One protocol implemented** | `apb_protocol` is the only backend `sfr` currently dispatches to; the `protocol` workbook field is otherwise unused |
| **Synchronizer is a placeholder** | `models/m_vlsi_synch.sv` is explicitly a generic 2-flop behavioral model ("please comment out ... and replace with your model") — using it unmodified in a real CDC path is a functional risk, not just a lint concern |
| **`gen_tb()` is unused** | The `sfr.gen_tb()` testbench-stub method exists in the tool but the CLI entry point at the bottom of `CSR_Generation.py` never calls it |
| **Same-cycle SW write is dropped on a HW-written field** | By design HW wins (see Design Description, Field Types). A SW write to a `rwi` field, or a SW clear of a `w1c` bit, that lands on the same edge as a HW write to that field is lost without any bus-level indication (`PSLVERR` is not raised); software must avoid racing the hardware on the same field |
| **No overlap/range checking** | The generator does not validate that register offsets are unique or that bit fields within a register don't overlap — a malformed workbook can silently produce broken RTL |

---

## Configuration Parameters

These come from the workbook's `Table - Configuration` block, not RTL `parameter`s — the generator
bakes them into the emitted module rather than leaving them runtime-configurable:

| Parameter | Source Cell | Description |
|-----------|-------------|--------------|
| `Module Name` | `Table - Configuration` | Name of the generated `.sv` module and file |
| `Protocol` | `Table - Configuration` | Bus protocol backend — only `apb` is implemented |
| `Data Width` | `Table - Configuration` | `i_pwdata`/`o_prdata` width in bits |
| `Address Width` | `Table - Configuration` | `i_paddr` width in bits |
| `Asynchronous` | `Table - Configuration` | `0` = single-clock (`i_bus_clk` only), `1` = dual-clock with the CDC bridge (adds `i_reg_clk`/`i_reg_rstn`) |
| Per-register `Offset` / `Reset Value` | `REGISTER` rows | Address decode value and per-field reset value |

---

## Compliance

| APB4 Feature | Supported |
|--------------|-----------|
| 2-phase SETUP/ACCESS transfer | ✅ |
| `PREADY` wait-state insertion | ⚠️ Fixed 1-cycle (sync) / handshake-bounded (async) — not driven by register-specific latency |
| `PSLVERR` error response | ✅ (protection / alignment / strobe) |
| `PPROT` protection qualifiers | ⚠️ Partial — only the secure/non-secure bit (`PPROT[1]`) is checked, gated by `i_protect_en` |
| `PSTRB` byte strobes | ⚠️ Checked, not honored — a partial-strobe write is rejected with `SLVERR` rather than performed |

---

## Revision History

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-03-06 | Initial version |
| 1.1 | 2026-09-20 | Fixed CDC bug in async template (Asynchronous=1): `o_prdata` was captured by an `always_ff @ (posedge i_bus_clk)` gated by `apb_read_en`, a signal generated entirely in the `i_reg_clk` domain, risking a missed/metastable read-data update across asynchronous clocks. `reg_prdata` now latches in the `i_reg_clk` domain (qualified by `apb_read_en`, same domain), and a new `reg_prdata_bus` FF resyncs it into the `i_bus_clk` domain using the already-synchronized `read_aclk_bus_clk_falling` pulse before driving `o_prdata`. Sync template (Asynchronous=0) unaffected. |
| 1.2 | 2026-09-27 | Documentation overhaul: added Interface Signals, Architecture (generation-pipeline flowchart + link to the interactive `docs/architecture.html` block diagram), Design Description (APB handshake sequence, field-type decision flowchart, CDC handshake writeup), a Register Map for the `CSR_Example.xlsx` worked example (`abc`/`def`, bit-layout diagrams + tables covering all four field types), Generation Workflow (workbook format, CLI usage, output layout), Constraints and Limitations, Configuration Parameters, and Compliance. No RTL or generator changes. |
| 1.3 | 2026-10-28 | Field priority changed so **HW wins over SW** on `rwi` and `w1c` fields (previously SW won). Fixes a HW event on a `w1c` field being lost when SW wrote any other field of the same register (the register-wide `we_reg` overrode the field's `i_hw_we_*`). Example RTL `RTL/m_vlsi_csr.sv` and `RTL/m_vlsi_async_csr.sv` regenerated. New testbench `sim/tests/csr_priority_test/` (see its `run.sh`) covers sync and async. The `Register_Description` sheet of the workbooks still says "Software write is higher priority" for `rwi` and must be updated. |

---

## Contact

For questions or support, please contact the IP provider.
