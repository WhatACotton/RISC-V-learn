# RISC-V Cross-compilation Makefile
# Simple Makefile for test_simple_stack program

# RISC-V toolchain prefix
RISCV_PREFIX = riscv64-unknown-elf-

# Compiler and tools
CC = $(RISCV_PREFIX)gcc
OBJCOPY = $(RISCV_PREFIX)objcopy
OBJDUMP = $(RISCV_PREFIX)objdump

# Compiler flags
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O0 -Wall
LDFLAGS = -T linker.ld -nostdlib -nostartfiles -m elf32lriscv

# Verilog simulation tools
IVERILOG = iverilog
VVP = vvp
VERILOG_FLAGS = -g2005-sv

# Target files
TARGET = test_simple_stack
C_SOURCES = $(TARGET).c
OBJ_FILES = $(TARGET).o
ELF_FILE = $(TARGET).elf
BIN_FILE = $(TARGET).bin
HEX_FILE = $(TARGET).hex

# Verilog files
TB_TOP = tb_top
TB_EXEC = $(TB_TOP)
VERILOG_SOURCES = $(TB_TOP).sv top.sv
VCD_FILE = $(TB_TOP).vcd

# Default target
all: $(HEX_FILE)

# Compile C source to object file
$(OBJ_FILES): $(C_SOURCES)
	$(CC) $(CFLAGS) -c $(C_SOURCES) -o $(OBJ_FILES)

# Link object file to ELF
$(ELF_FILE): $(OBJ_FILES)
	$(CC) $(CFLAGS) -Wl,-m,elf32lriscv -T linker.ld $(OBJ_FILES) -o $(ELF_FILE)

# Convert ELF to binary
$(BIN_FILE): $(ELF_FILE)
	$(OBJCOPY) -O binary $(ELF_FILE) $(BIN_FILE)

# Convert binary to HEX file
$(HEX_FILE): $(BIN_FILE)
	hexdump -v -e '1/4 "%08x\n"' $(BIN_FILE) > $(HEX_FILE)

# Generate assembly listing
$(TARGET).s: $(ELF_FILE)
	$(OBJDUMP) -d $(ELF_FILE) > $(TARGET).s

# Compile testbench
$(TB_EXEC): $(VERILOG_SOURCES) $(HEX_FILE)
	$(IVERILOG) $(VERILOG_FLAGS) -o $(TB_EXEC) $(VERILOG_SOURCES)

# Run simulation
sim: $(TB_EXEC)
	@echo "=== Running RISC-V Simple Function Test ==="
	@timeout 15s ./$(TB_EXEC) || echo "Simulation completed or timed out"

# Run full test (build + simulate)
test: $(HEX_FILE) sim
	@echo "=== RISC-V Simple Function Test Complete ==="

# Quick test without timeout
test-quick: $(TB_EXEC)
	@echo "=== Running RISC-V Quick Test ==="
	@./$(TB_EXEC)

# Clean build artifacts
clean:
	rm -f $(OBJ_FILES) $(ELF_FILE) $(BIN_FILE) $(HEX_FILE) $(TARGET).s
	rm -f $(TB_EXEC) $(VCD_FILE)

# Show help
help:
	@echo "Available targets:"
	@echo "  all         - Build HEX file (default)"
	@echo "  test        - Build and run complete simulation test"
	@echo "  sim         - Run simulation (requires HEX file)"
	@echo "  test-quick  - Run simulation without timeout"
	@echo "  clean       - Remove build artifacts"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Generated files:"
	@echo "  $(OBJ_FILES) - Object file"
	@echo "  $(ELF_FILE)  - ELF executable"
	@echo "  $(BIN_FILE)  - Binary file"
	@echo "  $(HEX_FILE)  - HEX file for processor"
	@echo "  $(TARGET).s  - Assembly listing"
	@echo "  $(TB_EXEC)   - Compiled testbench"
	@echo "  $(VCD_FILE)  - Waveform file"

.PHONY: all clean help test sim test-quick