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

## Build Notes

This repository does not include a complete Vivado project export. The intended workflow is to create or rebuild the Vivado block design manually using the RTL files and required Xilinx IP cores.

Required hardware components include:

MicroBlaze processor
AXI interconnect
3 AXI BRAM controllers with block memory generators for clause storage
UARTLite
Custom DMM solver IP
Xilinx Block Memory Generator IPs used inside the solver core

The BRAM IP configurations must match the widths and depths expected by the RTL.    
