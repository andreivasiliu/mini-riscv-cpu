simple1:
	riscv64-none-elf-as -march=rv32i simple.s
	riscv64-none-elf-objcopy -O binary a.out a.bin
	hexdump -e '1/4 "%08x\n"' a.bin > program.hex

simple2:
	riscv64-none-elf-gcc -O2 -march=rv32i -mabi=ilp32 simple2.c -nostdlib
	riscv64-none-elf-objcopy -O binary a.out a.bin
	hexdump -e '1/4 "%08x\n"' a.bin > program.hex
