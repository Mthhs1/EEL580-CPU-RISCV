# Relatorio Tecnico — CPU RISC-V RV32I em Verilog

## 1. Introducao

Este projeto descreve a implementacao de uma CPU RISC-V de 32 bits (RV32I) com pipeline de 5 estagios, utilizando Verilog para integracao no simulador Digital, atendendo aos requisitos do documento `Projeto_CPU_p1.pdf`.

## 2. Premissas Adotadas

- O subconjunto de instrucoes RV32I exigido pelo PDF foi implementado: `add`, `addi`, `auipc`, `sub`, `and`, `andi`, `or`, `ori`, `xor`, `xori`, `sll`, `slli`, `srl`, `srli`, `lw`, `lui`, `sw`, `jal`, `jalr`, `beq`, `bne`.
- As memorias de instrucao e dados sao externas a CPU, expostas via interfaces separadas (`imem_*` e `dmem_*`), permitindo o uso das memorias ROM e RAM do Digital.
- O sinal `load_enable_i` ativo em nivel alto congela toda a CPU durante a carga assincrona das memorias, preservando o estado interno (PC, pipeline e banco de registradores).
- O reset e assincrono (`reset_i`), zerando PC, pipeline e banco de registradores.
- Nao ha modo supervisor (S Mode); apenas o pipeline de inteiros foi implementado.
- A ALU foi implementada em Verilog (nao usando blocos combinacionais multi-bit do Digital), conforme recomendado pelo PDF.

## 3. Arquitetura do Pipeline

A CPU foi organizada em 5 estagios:

```
┌────┐    ┌────┐    ┌────┐    ┌─────┐    ┌────┐
│ IF │───►│ ID │───►│ EX │───►│ MEM │───►│ WB │
└────┘    └────┘    └────┘    └─────┘    └────┘
```

### 3.1 IF (Instruction Fetch)
- O `program_counter` mantem o PC atual e calcula PC+4.
- O endereco da instrucao e apresentado em `imem_addr_o` e a instrucao e lida de `imem_data_i`.
- Em caso de branch tomado ou jump, o PC e redirecionado para `target_addr_i`.

### 3.2 ID (Instruction Decode)
- O `instruction_decoder` extrai opcode, rd, rs1, rs2, funct3, funct7 e gera o imediato sign-extended para os formatos R, I, S, B, U e J.
- A `control_unit` decodifica o opcode e gera os sinais de controle: `reg_write`, `mem_to_reg`, `mem_write`, `mem_read`, `alu_src`, `alu_ctrl`, `branch`, `jump`, `auipc`, `jalr`, `lui`.
- O `register_file` realiza leitura assincrona de rs1 e rs2, com x0 sempre retornando zero.
- **Internal forwarding WB->ID**: quando o estagio WB esta escrevendo em um registrador que ID esta lendo no mesmo ciclo, o dado do WB e usado diretamente (bypass do mux interno), evitando o hazard write-before-read.

### 3.3 EX (Execute)
- A `forwarding_unit` seleciona a origem dos operandos A e B da ALU: valor do banco (00), forward do estagio MEM (01) ou forward do estagio WB (10). Prioridade MEM > WB.
- Para `auipc`, a entrada A da ALU recebe o PC; para `lui`, recebe zero; caso contrario, recebe rs1.
- A entrada B da ALU recebe o imediato (se `alu_src=1`) ou rs2.
- A `alu` executa: ADD, SUB, AND, OR, XOR, SLL, SRL e PASS_B (para LUI).
- O `branch_comparator` compara rs1 e rs2 para `beq` e `bne`.
- O endereco de destino de branch/jump e calculado: `PC + imm` para branches e JAL; `rs1 + imm` (com bit 0 = 0) para JALR.

### 3.4 MEM (Memory Access)
- O endereco de memoria de dados e o resultado da ALU (`dmem_addr_o`).
- Para `sw`, o dado de rs2 e escrito (`dmem_wdata_o` com `dmem_we_o`).
- Para `lw`, o dado e lido de `dmem_rdata_i`.
- A escrita e suprimida quando `load_enable_i` esta ativo.

### 3.5 WB (Write Back)
- Para `jal`/`jalr`, o valor escrito no registrador de destino e PC+4 (endereco de retorno).
- Para `lw`, o dado lido da memoria.
- Para demais instrucoes, o resultado da ALU.

## 4. Tratamento de Hazards

### 4.1 Data Hazards (RAW)

**Forwarding EX/MEM e EX/WB**: A `forwarding_unit` detecta dependencias entre a instrucao no EX e as instrucoes nos estagios MEM e WB. Se houver dependencia, o operando e encaminhado diretamente, evitando stall.

**Internal forwarding WB->ID**: Quando uma instrucao no WB escreve em um registrador que uma instrucao no ID esta lendo no mesmo ciclo, a escrita sincrona do banco ainda nao ocorreu. Um mux combinacional seleciona o dado do WB diretamente para o ID/EX register, evitando o hazard write-before-read.

### 4.2 Load-Use Hazard

Quando uma instrucao de load esta no EX e a instrucao no ID depende do resultado do load, a `hazard_unit` gera:
- Stall no IF e ID (PC e IF/ID mantem seus valores)
- Flush no EX (ID/EX recebe NOP)
- Um ciclo de bolha e inserido, permitindo que o load chegue ao MEM/WB antes que a instrucao dependente precise do dado no EX.

### 4.3 Control Hazards

Branches sao resolvidos no estagio EX. Quando um branch e tomado ou um jump e executado:
- Flush no IF/ID e ID/EX (descarta as instrucoes incorretas nos estagios IF e ID)
- O PC e redirecionado para o endereco de destino

## 5. Registradores de Pipeline

Quatro registradores de pipeline separam os estagios:

| Registrador | Funcao |
|-------------|--------|
| IF/ID | Armazena PC, PC+4 e instrucao entre fetch e decode |
| ID/EX | Armazena PC, PC+4, dados de rs1/rs2, imediato, enderecos de registradores e sinais de controle |
| EX/MEM | Armazena PC+4, resultado da ALU, dado de rs2, endereco de rd e sinais de controle |
| MEM/WB | Armazena PC+4, resultado da ALU, dado da memoria, endereco de rd e sinais de controle |

Todos suportam:
- Reset assincrono (zera todos os campos)
- `load_enable_i` (congela o registrador durante carga de memoria)
- Flush (carga NOP — instrucao `0x00000013` para IF/ID, controles zerados para ID/EX)
- Stall (mantem valor atual)

## 6. Pausa Durante Carga de Memoria

O sinal `load_enable_i` ativo em nivel alto congela:
- O contador de programa (PC nao incrementa)
- Todos os registradores de pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB)
- A escrita na memoria de dados e suprimida (`dmem_we_o = 0`)

Isso permite que as memorias ROM e RAM sejam carregadas assincronamente enquanto a CPU mantem seu estado interno corrente.

## 7. Sinais de Debug

Os seguintes sinais internos sao exportados para afericao no Digital:

| Sinal | Bits | Descricao |
|-------|------|-----------|
| `pc_debug_o` | 32 | PC atual (estagio IF) |
| `instr_debug_o` | 32 | Instrucao atual (estagio ID) |
| `alu_result_debug_o` | 32 | Resultado da ALU (estagio EX) |
| `alu_carry_debug_o` | 1 | Carry da ALU (debug do somador) |
| `alu_overflow_debug_o` | 1 | Overflow da ALU (debug do somador) |
| `reg_debug_o` | 32 | Valor do registrador selecionado por `reg_sel_i` |
| `stage_if_pc_o` | 32 | PC no estagio IF |
| `stage_id_pc_o` | 32 | PC no estagio ID |
| `stage_ex_pc_o` | 32 | PC no estagio EX |
| `hazard_stall_o` | 1 | Indicador de stall ativo |
| `hazard_flush_o` | 1 | Indicador de flush ativo |

A ALU exporta `carry_o` e `overflow_o` para depuracao do somador, conforme sugerido no PDF.

## 8. Modulos do Projeto

| Arquivo | Modulo | Descricao |
|---------|--------|-----------|
| `riscv_cpu.v` | `riscv_cpu` | Top-level, integra todos os componentes |
| `alu.v` | `alu` | ALU com ADD, SUB, AND, OR, XOR, SLL, SRL, PASS_B |
| `branch_comparator.v` | `branch_comparator` | Comparador para beq/bne |
| `control_unit.v` | `control_unit` | Unidade de controle principal |
| `forwarding_unit.v` | `forwarding_unit` | Data forwarding (bypass) |
| `hazard_unit.v` | `hazard_unit` | Deteccao de hazards de dados e controle |
| `instruction_decoder.v` | `instruction_decoder` | Decoder + gerador de imediatos |
| `pipeline_regs.v` | `if_id_reg`, `id_ex_reg`, `ex_mem_reg`, `mem_wb_reg` | Registradores de pipeline |
| `program_counter.v` | `program_counter` | Contador de programa |
| `register_file.v` | `register_file` | Banco de 32 registradores de 32 bits |

O arquivo `riscv_cpu_all.v` contem todos os modulos concatenados em um unico arquivo, para uso no simulador Digital (que requer um unico arquivo por componente externo).

## 9. Validacao

### 9.1 Testbench Automatizado

O arquivo `tb_riscv_cpu.v` implementa um testbench automatizado com iverilog que:
1. Carrega um programa de 49 instrucoes cobrindo todas as instrucoes exigidas
2. Gera clock e sequencia de reset
3. Executa 70 ciclos
4. Verifica 31 registradores e 2 posicoes de memoria contra valores esperados

### 9.2 Simulacao no Digital

O arquivo `test_circuit.dig` contem um circuito pronto para o simulador Digital, com:
- ROM pre-carregada com o programa de teste (49 instrucoes)
- RAM dual-port para dados
- Clock e pinos de entrada (`Reset`, `load_enable`, `reg_sel`)
- Probes de saida para todos os sinais de debug

Para executar:
1. Abrir `test_circuit.dig` no Digital
2. Com `Reset = 1`, clicar no Clock uma vez
3. Mudar `Reset = 0`
4. Clicar no Clock repetidamente e observar os probes (`ALU_Result`, `Reg_Debug`, `PC_Debug`, etc.)
5. Usar `reg_sel` para inspecionar registradores individuais

### 9.3 Resultados dos Testes

```
========================================
  RESULTADOS DOS TESTES
========================================
[PASS] addi x1: x1 = 0x00000005
[PASS] addi x2: x2 = 0x00000003
[PASS] add  x3: x3 = 0x00000008
[PASS] sub  x4: x4 = 0x00000002
[PASS] and  x5: x5 = 0x00000001
[PASS] or   x6: x6 = 0x00000007
[PASS] xor  x7: x7 = 0x00000006
[PASS] andi x8: x8 = 0x00000001
[PASS] ori  x9: x9 = 0x0000000d
[PASS] xori x10: x10 = 0x00000000
[PASS] slli x12: x12 = 0x00000040
[PASS] srli x13: x13 = 0x00000004
[PASS] sll  x14: x14 = 0x00000080
[PASS] srl  x15: x15 = 0x00000002
[PASS] lw   x17: x17 = 0x00000064
[PASS] lui  x18: x18 = 0x12345000
[PASS] auipc x19: x19 = 0x0000004c
[PASS] beq  x20: x20 = 0x00000007
[PASS] bne  x21: x21 = 0x0000002a
[PASS] bne  x22: x22 = 0x0000000b
[PASS] jal  x23/x24: retorno e desvio corretos
[PASS] jalr x26/x27: retorno e desvio corretos
[PASS] forwarding x28: x28 = 0x00000012
[PASS] load-use x31: x31 = 0x000000cd
[PASS] mem[0] = 0x00000064
[PASS] mem[1] = 0x000000c8
========================================
  TODOS OS TESTES PASSARAM (0 erros)
========================================
```

### 9.4 Categorias Testadas

| Categoria | Instrucoes | Status |
|-----------|-----------|--------|
| Aritmeticas | add, addi, sub, auipc | PASS |
| Logicas | and, andi, or, ori, xor, xori | PASS |
| Deslocamento | sll, slli, srl, srli | PASS |
| Memoria | lw, sw, lui | PASS |
| Controle | jal, jalr, beq, bne | PASS |
| Forwarding | cadeia de dependencias | PASS |
| Load-use hazard | sw -> lw -> add | PASS |
| Control hazard | flush em branch/jump | PASS |

### 9.5 Como Reproduzir os Testes

```bash
iverilog -g2012 -s tb_riscv_cpu -o tb.out tb_riscv_cpu.v alu.v branch_comparator.v control_unit.v forwarding_unit.v hazard_unit.v instruction_decoder.v pipeline_regs.v program_counter.v register_file.v riscv_cpu.v
vvp tb.out
```
