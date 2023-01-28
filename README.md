# mini-riscv-cpu

This is a hobby project to learn how to make a 32-bit RISC-V CPU on an FPGA.

This is made for the [Alchitry Cu] board with an [Alchitry Io] expansion.

Currently it can execute the basic rv32i instruction-set, but is missing CSRs,
an interrupt controller, external RAM, an MMU, and peripherals.

It uses a very naive implementation which takes 60% of the iCE40HX8K FPGA's LUT
capacity for the core and 80% of BRAM capacity for registers and memory. It can
run at ~40MHz (out of 100MHz), and takes four cycles for an instruction.

[Alchitry Cu]: https://alchitry.com/boards/cu
[Alchitry Io]: https://alchitry.com/boards/cu-1-1

## Build

This uses the `apio` toolchain, and building the FPGA gateware should be as easy as `apio build` and `apio upload`.

To compile the program that's pre-loaded into RAM, a `gcc` toolchain with the `riscv32` or `riscv64` target is required.

## Files

* [`alchitry.v`](alchitry.v) - Top-level Verilog module that fixes some of Alchitry's issues
* [`main.v`](main.v) - Main module that hooks the CPU up to the board's LEDs
* [`riscv_core.v`](riscv_core.v) - The RISC-V CPU core
* [`simple1.s`](simple1.s) and [`simple2.c`](simple2.c) - Example working programs that can run on the CPU
