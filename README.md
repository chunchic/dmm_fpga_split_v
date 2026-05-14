# DMM FPGA Split-V Solver

This repository contains an FPGA implementation of a fixed-point Digital Memcomputing Machine (DMM) solver for planted 3-SAT instances. The design is based on a split-variable architecture that stores and updates the contributions to each variable separately, allowing clause-wise processing with BRAM-based storage.

The project targets a Xilinx VCU118 FPGA board (can be reconfigured) and uses a custom AXI4-Lite IP core controlled by a MicroBlaze processor from Vitis.

## Overview

Digital Memcomputing Machines solve optimization problems by mapping them to nonlinear dynamical systems. For 3-SAT, the Boolean variables are represented by continuous variables, and the solver evolves the corresponding DMM equations using fixed-point arithmetic.

This implementation processes clauses in a streaming pipeline. Clause data are stored in external BRAMs, while the solver core updates internal state variables using a ping-pong BRAM structure. The design avoids instance-specific full parallelization and is intended to scale to larger problem sizes by reusing the same pipelined datapath.

## Main Features

- Fixed-point DMM solver for 3-SAT
- Split-variable representation of the variable update
- Clause-by-clause streaming architecture
- Ping-pong BRAM structure for variable accumulation
- AXI4-Lite control interface
- MicroBlaze/Vitis software for loading clauses and starting the solver
- External BRAM interface for clause storage
- Runtime configuration of:
  - number of variables
  - number of clauses
  - integration step shift

## Clause BRAM Format

The software writes each clause into three separate BRAMs. Each BRAM stores one literal position for all clauses.

For clause m:

BRAM1[m] = literal 1
BRAM2[m] = literal 2
BRAM3[m] = literal 3

Each literal is packed into a 32-bit word:

bits [31:1] = variable index
bit  [0]    = literal sign / polarity

The solver reads one clause per cycle from the three BRAMs.

## Software Flow

The Vitis software performs the following steps:

Initializes UARTLite.
Receives a header from the host:
magic word
number of variables
number of clauses
Receives clause data over UART.
Writes the three literal streams into external BRAMs.
Writes solver configuration registers.
Starts the solver through REG_START.
Polls REG_DONE.
Reads back the number of solver steps and clock cycles.

The current base addresses used by the Vitis code are:

#define BRAM1_BASE_ADDR    0xC0000000
#define BRAM2_BASE_ADDR    0xC2000000
#define BRAM3_BASE_ADDR    0xC4000000
#define SOLVER_IP_ADDR     0x44A00000

These addresses must match the Vivado block design address map.



## Running the Solver

The design is controlled from Vitis through a MicroBlaze application. The FPGA bitstream must be generated in Vivado first, then exported to Vitis together with the hardware description.

In Vivado:

1. Rebuild the block design.
2. Generate the output products.
3. Create the HDL wrapper.
4. Run synthesis and implementation.
5. Generate the bitstream.

After the bitstream is generated, export the hardware:
File -> Export -> Export Hardware

Open Vitis and create a new application project using the exported .xsa file.

Use the provided Vitis source code from:

software/vitis/main.c

Build the application.
After the application starts, it initializes UARTLite and waits for input from the host computer.

After the Vitis application is running, start the MATLAB script that sends the problem instance over UART.

The expected data order is:

MAGIC_WORD
number of variables
number of clauses
literal 1 of clause 0
literal 2 of clause 0
literal 3 of clause 0
literal 1 of clause 1
literal 2 of clause 1
literal 3 of clause 1
...

The Vitis application writes the three literal streams into the three external clause BRAMs, configures the solver registers, starts the solver, waits for completion, and prints the result.

A normal run should print something similar to:

n=1000 n_clause=4300
upload done
done
steps=...
clk_counter=...
donezo

The exact number of steps and clock cycles depends on the problem instance.
