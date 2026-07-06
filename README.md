# CPU RISC-V 32-bit Pipeline (RV32I) em Verilog

Implementacao em **Verilog** de uma CPU **RISC-V RV32I** com **pipeline de 5 estagios**, guiada pelos requisitos do **PDF `Projeto_CPU_p1.pdf`**.

## Caracteristicas

- Arquitetura `RV32I` com o subconjunto inteiro pedido
- Pipeline de 5 estagios: `IF`, `ID`, `EX`, `MEM`, `WB`
- Detecao de hazards + forwarding
- Memorias separadas para instrucoes e dados
- Sinal `reset_i`
- Sinal `load_enable_i` para congelar a CPU durante carga assincrona de memoria
- Sinais de debug para afericao dos estados internos

## Instrucoes suportadas

| Tipo | Instrucoes |
|------|------------|
| Aritmeticas | `add`, `addi`, `auipc`, `sub` |
| Logicas | `and`, `andi`, `or`, `ori`, `xor`, `xori` |
| Deslocamento | `sll`, `slli`, `srl`, `srli` |
| Memoria | `lw`, `lui`, `sw` |
| Controle | `jal`, `jalr`, `beq`, `bne` |

## Arquivos principais

- `riscv_cpu.v` — top-level da CPU
- `alu.v`, `branch_comparator.v`, `control_unit.v`, `forwarding_unit.v`, `hazard_unit.v`, `instruction_decoder.v`, `pipeline_regs.v`, `program_counter.v`, `register_file.v` — modulos internos
- `riscv_cpu_all.v` — todos os modulos concatenados (para o Digital)
- `test_circuit.dig` — circuito pronto no Digital com ROM, RAM, Clock e probes de debug
- `tb_riscv_cpu.v` — testbench automatizado (32 testes, todos PASS)

## Documentacao

- `TUTORIAL_SETUP.md` — guia de uso no simulador Digital
- `REFERENCIA_INSTRUCOES.md`
- `relatorio.md` / `relatorio.tex` — relatorio tecnico completo

## Validacao

- **Digital**: abra `test_circuit.dig` no simulador, siga as instrucoes em `TUTORIAL_SETUP.md`
- **Icarus Verilog**: `iverilog -g2012 -s tb_riscv_cpu -o tb.out tb_riscv_cpu.v *.v && vvp tb.out` — 32/32 testes passam
