# Direct-Mapped Write-Back Cache Controller (Verilog)

A synthesizable **direct-mapped, write-back, write-allocate cache controller** written in Verilog and verified in **Xilinx Vivado** with a self-checking testbench.

![Language](https://img.shields.io/badge/HDL-Verilog-blue) ![Tool](https://img.shields.io/badge/Tool-Vivado-red) ![Status](https://img.shields.io/badge/Simulation-Passing-brightgreen)

---

## Overview

A cache sits between the CPU and main memory and keeps recently used data close to the processor. The cache controller is the FSM that decides, for every CPU request, whether the data is already in the cache (**hit**) or must be fetched from main memory (**miss**). It also handles tag comparison, line replacement and writing modified (dirty) data back to memory.

This project implements that controller along with the cache storage array, a behavioral main-memory model and a self-checking testbench.

## Features

- Direct-mapped placement (one line per index)
- Write-back policy with a dirty bit per line
- Write-allocate on write misses
- 7-state FSM with a dirty-victim write-back path
- 4-word block transfers (burst read and write)
- Fully parameterized widths (address, data, index, offset)
- Self-checking testbench with pass/fail summary

## Cache Configuration

| Parameter | Value |
|---|---|
| Address width | 32 bits (byte address) |
| Data width | 32 bits |
| Number of lines | 64 (`INDEX_WIDTH = 6`) |
| Block size | 4 words = 16 bytes (`OFFSET_WIDTH = 2`) |
| Cache size | 64 x 16 B = 1 KB |
| Tag width | 22 bits |
| Placement | Direct-mapped |
| Write policy | Write-back, write-allocate |

### Address Breakdown

```
 31                    10 9      4 3     2 1    0
+------------------------+--------+-------+------+
|        TAG (22)        | INDEX  | WORD  | BYTE |
|                        |  (6)   | SEL(2)| (2)  |
+------------------------+--------+-------+------+
```

A **hit** occurs when `valid[index] == 1` and `tag_array[index] == TAG` of the requested address.

## Architecture

```
          +-----+      +-------------------+      +--------------+
          | CPU | <--> |  cache_controller | <--> | main_memory  |
          +-----+      |       (FSM)       |      | (sim model)  |
                       +---------+---------+      +--------------+
                                 |
                                 v
                       +-------------------+
                       |     cache_mem     |
                       | tag / valid /     |
                       | dirty / data      |
                       +-------------------+
```

| Module | Role |
|---|---|
| `cache_top` | Top-level wrapper connecting the controller and the storage array |
| `cache_controller` | FSM and all control logic |
| `cache_mem` | Tag, valid, dirty and data arrays |
| `main_memory` | Behavioral memory with fixed latency (simulation only) |
| `tb_cache` | Self-checking testbench (simulation only) |

## FSM States

| State | Function |
|---|---|
| `IDLE` | Wait for `cpu_req`; latch address, write data and write-enable |
| `COMPARE` | Compare stored tag with the request tag to decide hit or miss |
| `WB_CHECK` | On a miss, check whether the victim line is valid and dirty |
| `WRITE_BACK` | Write the 4 words of the dirty victim line to main memory |
| `ALLOCATE` | Fetch the requested 4-word block from main memory into the line |
| `UPDATE` | Perform the CPU read or write on the resident line (write sets the dirty bit) |
| `DONE` | Assert `cpu_ready` for one cycle, then return to `IDLE` |

Flow: `IDLE -> COMPARE -> (hit) UPDATE -> DONE` or `COMPARE -> (miss) WB_CHECK -> [WRITE_BACK] -> ALLOCATE -> UPDATE -> DONE`

## Repository Structure

```
.
├── cache_top.v          # Top-level wrapper        (design)
├── cache_controller.v   # FSM / control logic      (design)
├── cache_mem.v          # Storage arrays           (design)
├── main_memory.v        # Behavioral memory model  (simulation only)
├── tb_cache.v           # Self-checking testbench  (simulation only)
└── README.md
```

## How to Run in Vivado

1. **Create project:** RTL Project, choose any part (for example `xc7a35tcpg236-1` for Basys3).
2. **Design sources:** add `cache_top.v`, `cache_controller.v`, `cache_mem.v` and set `cache_top` as top.
3. **Simulation sources:** add `main_memory.v` and `tb_cache.v` and set `tb_cache` as the simulation top.
4. Click **Run Simulation -> Run Behavioral Simulation**.
5. In the Tcl console type `run all`. The test completes at about 1040 ns.
6. To view the circuit: **RTL Analysis -> Open Elaborated Design -> Schematic**.
7. To synthesize: **Run Synthesis** and open the Utilization and Timing reports.

> **Note:** `main_memory.v` and `tb_cache.v` must stay under *Simulation Sources* only. They are not synthesizable.

## Verification

The testbench issues each CPU transaction through a reusable `do_access` task, waits for `cpu_ready`, and automatically checks the hit flag and returned data.

| Test | Address | Operation | What it verifies |
|---|---|---|---|
| T1 | `0x000` | Read | Cold (compulsory) miss and block allocate |
| T2 | `0x000` | Read | Read hit on the freshly filled line |
| T3 | `0x004` | Write `0xDEADBEEF` | Write hit, single-word write, dirty bit set |
| T4 | `0x004` | Read | Written data read back correctly |
| T5 | `0x400` | Read | Conflict miss (same index, different tag) forcing dirty write-back and allocate |
| T6 | `0x004` | Read | Evicted data was written back to memory and is restored as `0xDEADBEEF` |

### Expected Output

```
[T1] addr=00000000 we=0 hit=0 rdata=00000000
[T2] addr=00000000 we=0 hit=1 rdata=00000000
[T3] addr=00000004 we=1 hit=1 rdata=deadbeef
[T4] addr=00000004 we=0 hit=1 rdata=deadbeef
[T5] addr=00000400 we=0 hit=0 rdata=00000400
[T6] addr=00000004 we=0 hit=0 rdata=deadbeef

==== ALL TESTS PASSED (6 checks) ====
```

### Waveform

*(Add a screenshot of the T5 transaction here, showing `state`, `burst_cnt`, `mem_req`, `mem_ready`, `cpu_hit` and `cpu_ready`.)*

```
![T5 waveform](images/t5_waveform.png)
```

## Synthesis Results

*(Fill in from your Vivado reports: Synthesis -> Open Synthesized Design -> Report Utilization / Report Timing.)*

| Resource | Used |
|---|---|
| LUTs | _fill in_ |
| Flip-flops | _fill in_ |
| LUTRAM / BRAM | _fill in_ |
| Worst negative slack @ 100 MHz | _fill in_ |

The 64 x 128-bit data array has a combinational read, so Vivado infers it as distributed RAM (LUTRAM) rather than block RAM.

> Implementation (place and route) is not targeted because `cache_top` exposes wide 32-bit buses that exceed the pin count of typical development boards. To run on hardware, wrap the cache in a small test sequencer driven by switches and buttons.

## Design Notes and Bugs Fixed

Issues found and fixed during verification:

1. **Registered status reads.** Tag, valid and dirty outputs were registered, so the `COMPARE` state saw the previous line's data. Fixed by making these reads combinational.
2. **Byte vs. word addressing.** The word-select field was taken from `addr[1:0]` instead of `addr[3:2]`, making neighbouring words indistinguishable. Fixed the field extraction and index position.
3. **Block-fill word order.** Fetched words were concatenated in reverse order, swapping word 0 and word 3 on every fill. Fixed the concatenation order.
4. **Control-signal timing.** Registered write-enables arrived one cycle late relative to the FSM state change. Fixed by driving enables combinationally from the current state.
5. **Index source.** The storage array was indexed from the raw CPU address instead of the latched address. Fixed so the index stays stable for the whole multi-cycle transaction.

## Possible Extensions

- Set-associative version with LRU replacement
- Write-through mode selectable by a parameter
- AXI-Lite / AHB-Lite memory-side interface
- Hit and miss performance counters with trace-driven hit-rate analysis
- Non-blocking miss handling with miss-status registers
- FPGA demo with a switch/button test sequencer and 7-segment display

## Tools

- Xilinx Vivado (simulation and synthesis)
- Verilog HDL

## Author

*Barnomoy Mandal* 

## License

Released for educational use. 

