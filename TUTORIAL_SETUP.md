# Tutorial de Setup

## Objetivo

Este repositorio contem uma CPU RISC-V RV32I de 32 bits com pipeline de 5 estagios em Verilog, integravel no simulador Digital.

## Arquivos principais

| Arquivo | Descricao |
|---------|-----------|
| `riscv_cpu.v` | Top-level da CPU (modulos separados) |
| `riscv_cpu_all.v` | Todos os modulos concatenados (para o Digital) |
| `test_circuit.dig` | Circuito pronto no Digital com ROM, RAM, Clock e probes |
| `tb_riscv_cpu.v` | Testbench automatizado (iverilog standalone) |

## Uso com o simulador Digital

### Passo 1: Abrir o circuito

Abra o arquivo `test_circuit.dig` no simulador Digital. O circuito ja contem:
- CPU RISC-V (carregada de `riscv_cpu_all.v`)
- ROM com programa de teste (49 instrucoes)
- RAM dual-port para dados
- Clock
- Pinos de entrada: `Reset`, `load_enable`, `reg_sel`
- Probes de saida: `PC_Debug`, `Instr_Debug`, `ALU_Result`, `Reg_Debug`, `Stage_IF/ID/EX_PC`, `Hazard_Stall`, `Hazard_Flush`
- Caso não funcione, abra o arquivo, clique no componente da CPU e altere o caminho do arquivo `riscv_cpu_all.v` para o local correto.

### Passo 2: Configurar entradas

| Entrada | Valor inicial | Apos 1 ciclo de clock |
|---------|--------------|----------------------|
| `Reset` | **1** (HIGH) | **0** (LOW) |
| `load_enable` | **0** (LOW) | mantem **1** |
| `reg_sel` | qualquer (0-31) | ajuste para observar registrador desejado |

### Passo 3: Executar

1. Com `Reset = 1`, clique no Clock **uma vez** (reseta PC, pipeline e registradores)
2. Mude `Reset = 0`
3. Clique no Clock repetidamente para executar o programa
4. Observe os probes:
   - `ALU_Result`: resultado atual da ALU no estagio EX
   - `Reg_Debug`: valor do registrador selecionado por `reg_sel`
   - `PC_Debug`: contador de programa atual
   - `Instr_Debug`: instrucao sendo executada
   - `Stage_IF/ID/EX_PC`: PC em cada estagio do pipeline
   - `Hazard_Stall`/`Hazard_Flush`: indicadores de hazard

### Passo 4: Inspecionar registradores

Use `reg_sel` (0-31) para selecionar qual registrador aparece em `Reg_Debug`:
- `reg_sel = 1` mostra x1
- `reg_sel = 10` mostra x10 (a0)
- `reg_sel = 0` mostra x0 (sempre 0)

### Pausar a CPU

Para inspecionar o estado sem avancar o pipeline:
1. Mude `load_enable = 1` (congela a CPU)
2. Observe os probes
3. Mude `load_enable = 0` para retomar

## Trocar o programa na ROM

Para testar um programa diferente:
1. Abra `test_circuit.dig` no Digital
2. Duplo-clique na ROM
3. Substitua os dados hexadecimais pelas novas instrucoes (uma por linha, sem `0x`)
4. Clique em OK

## Compilacao standalone com Icarus Verilog

```bash
iverilog -g2012 -s riscv_cpu -o /tmp/riscv_cpu.out \
  alu.v branch_comparator.v control_unit.v forwarding_unit.v \
  hazard_unit.v instruction_decoder.v pipeline_regs.v \
  program_counter.v register_file.v riscv_cpu.v
```

## Reset e pausa

- `reset_i = 1` zera PC, pipeline e banco de registradores.
- `load_enable_i = 1` congela o estado interno da CPU.
