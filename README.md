# RISC-V-learn

This repository is aiming to gain a better understanding of RISC-V architecture.

The CPU is supported RV32I instruction set so far. And is implemented in SystemVerilog.

## Developed with Vibe Coding

This project is based on [my RISC-V CPU implementation with Chisel](https://github.com/WhatACotton/chisel-riscv). I tried to replace the Chisel code with SystemVerilog, and I used AI copilot to help me with the conversion. The code is not perfect, but it works.

## Usage

Testing the CPU is done with a simple testbench, which is also written in SystemVerilog. Icarus Verilog is used as the simulator. You can run the testbench with the following command:

```bash
make test
```

If you want to modify the C code, you can edit the `test_simple_stack.c` file. The C code is compiled to a binary file, which is then loaded into the CPU's memory. You can also modify the testbench to add more tests.
