@echo off
iverilog -g2012 -s riscv_cpu -o riscv_cpu.out ^
  alu.v branch_comparator.v control_unit.v forwarding_unit.v ^
  hazard_unit.v instruction_decoder.v pipeline_regs.v ^
  program_counter.v register_file.v riscv_cpu.v

echo Compilacao concluida.
