
# AXI4-Lite FIFO Controller

## Overview

This project implements an AXI4-Lite controlled FIFO peripheral in Verilog. The design exposes a small memory-mapped register interface through which an AXI4-Lite master can write data into a synchronous FIFO, read data back from the FIFO, and monitor FIFO status/error conditions.

The project was developed to understand AXI4-Lite handshaking, memory-mapped register design, FIFO control logic, and basic RTL verification using a Verilog testbench.

## Features

* AXI4-Lite slave interface with separate write and read channels
* Memory-mapped register interface for FIFO access and status monitoring
* Synchronous FIFO with full, empty, overflow, underflow, and level tracking
* Status and error registers for debug and control
* Testbench with AXI-style write and read tasks
* Verified basic write-read operation through simulation waveform

## Block Diagram

```text
AXI4-Lite Master Testbench
          |
          |  AW/W/B/AR/R Channels
          v
AXI4-Lite Slave Register Interface
          |
          |  fifo_wr_en / fifo_rd_en
          v
Synchronous FIFO
```

## Register Map

| Address | Register     | Access | Description                                                       |
| ------- | ------------ | ------ | ----------------------------------------------------------------- |
| `0x00`  | CONTROL      | Write  | Control register. Used for clearing error flags.                  |
| `0x04`  | STATUS       | Read   | FIFO status summary: full, empty, overflow, underflow, any error. |
| `0x08`  | DATA_IN      | Write  | Writing to this address pushes data into the FIFO.                |
| `0x0C`  | DATA_OUT     | Read   | Reading from this address pops data from the FIFO.                |
| `0x10`  | FIFO_LEVEL   | Read   | Shows the current number of valid entries in FIFO.                |
| `0x14`  | ERROR_STATUS | Read   | Shows detailed error flags.                                       |

## STATUS Register Bit Mapping

| Bit      | Signal          | Description                        |
| -------- | --------------- | ---------------------------------- |
| `[0]`    | `fifo_full`     | FIFO is full                       |
| `[1]`    | `fifo_empty`    | FIFO is empty                      |
| `[2]`    | `err_overflow`  | Write attempted when FIFO was full |
| `[3]`    | `err_underflow` | Read attempted when FIFO was empty |
| `[4]`    | `any_error`     | Any error flag is active           |
| `[31:5]` | Reserved        | Reads as zero                      |

## ERROR_STATUS Register Bit Mapping

| Bit      | Error                 | Description                             |
| -------- | --------------------- | --------------------------------------- |
| `[0]`    | Overflow              | Write attempted when FIFO was full      |
| `[1]`    | Underflow             | Read attempted when FIFO was empty      |
| `[2]`    | Invalid Write Address | Write attempted to unsupported address  |
| `[3]`    | Invalid Read Address  | Read attempted from unsupported address |
| `[4]`    | WSTRB Error           | Unsupported partial write strobe        |
| `[31:5]` | Reserved              | Reads as zero                           |

## Design Details

### AXI4-Lite Write Path

The write path uses the AXI4-Lite write address, write data, and write response channels:

* `AWADDR` selects the target register.
* `WDATA` carries the write data.
* `WSTRB` is checked to ensure full 32-bit writes.
* `BRESP` returns `OKAY`, `SLVERR`, or `DECERR`.

When the master writes to the `DATA_IN` register, the controller generates a FIFO write enable pulse and passes `WDATA` into the FIFO.

### AXI4-Lite Read Path

The read path uses the AXI4-Lite read address and read data channels:

* `ARADDR` selects the register to read.
* `RDATA` returns register data or FIFO output data.
* `RRESP` returns read response status.

Reading the `DATA_OUT` register pops one word from the FIFO. Since the FIFO read output is registered, the read FSM includes wait states before asserting `RVALID` with valid FIFO data.

### FIFO

The FIFO is a synchronous FIFO with parameterized data width and depth. It tracks:

* write pointer
* read pointer
* current level
* full/empty status
* overflow/underflow events

## Verification

A Verilog testbench is used as an AXI4-Lite master. It provides reusable tasks for AXI write and AXI read transactions.

Verified operation:

1. Reset is applied and released.
2. A 32-bit data word is written to the `DATA_IN` register.
3. The FIFO stores the written data.
4. The same data is read back from the `DATA_OUT` register.
5. The read data matches the written data in simulation.

Example verified data:

```text
Written Data : 0xA0C21113
Read Data    : 0xA0C21113
```

## Files

```text
rtl/
  axi_lite_slave.v
  sync_fifo.v

tb/
  axi_lite_master_tb.v
```

## Tools Used

* Verilog HDL
* Xilinx Vivado
* XSim Simulator

## Current Limitations

* The design supports AXI4-Lite single-register transactions only.
* AXI burst transfers are not supported because AXI4-Lite does not include burst support.
* Partial writes using `WSTRB` are currently treated as an error.
* The current verification is based on directed simulation tests.

## Possible Future Improvements

* Add more directed test cases for overflow, underflow, invalid address, and clear-error operation.
* Add assertions for AXI handshaking rules.
* Add interrupt output for FIFO status/error events.
* Package the design as a Vivado custom IP.
* Extend the design to support a full memory-to-memory data mover using AXI4-Full or AXI-Stream.

