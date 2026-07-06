# Referencia de Instrucoes RV32I

## Aritmeticas

- `add rd, rs1, rs2`
- `addi rd, rs1, imm`
- `sub rd, rs1, rs2`
- `auipc rd, imm`

## Logicas

- `and rd, rs1, rs2`
- `andi rd, rs1, imm`
- `or rd, rs1, rs2`
- `ori rd, rs1, imm`
- `xor rd, rs1, rs2`
- `xori rd, rs1, imm`

## Deslocamento

- `sll rd, rs1, rs2`
- `slli rd, rs1, shamt`
- `srl rd, rs1, rs2`
- `srli rd, rs1, shamt`

## Memoria

- `lw rd, imm(rs1)`
- `sw rs2, imm(rs1)`
- `lui rd, imm`

## Controle

- `beq rs1, rs2, imm`
- `bne rs1, rs2, imm`
- `jal rd, imm`
- `jalr rd, rs1, imm`

## Observacoes de implementacao

- Branches sao resolvidos no estagio `EX`.
- `jal` e `jalr` escrevem `PC + 4` no registrador de destino.
- `lui` usa o imediato diretamente no caminho da ALU.
- `auipc` soma `PC + imediato`.
