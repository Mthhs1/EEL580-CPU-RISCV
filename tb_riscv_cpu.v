// =============================================================================
// Testbench para a CPU RISC-V com programa de teste completo.
// Cobre todas as instrucoes exigidas pelo PDF + hazards.
// =============================================================================
`timescale 1ns/1ps

module tb_riscv_cpu;

    reg         clk;
    reg         reset;
    reg         load_enable;
    reg  [4:0]  reg_sel;
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [31:0] pc_debug;
    wire [31:0] instr_debug;
    wire [31:0] alu_result_debug;
    wire [31:0] reg_debug;
    wire [31:0] stage_if_pc;
    wire [31:0] stage_id_pc;
    wire [31:0] stage_ex_pc;
    wire        hazard_stall;
    wire        hazard_flush;
    wire        alu_carry_debug;
    wire        alu_overflow_debug;

    integer i;
    integer errors;

    // -----------------------------------------------------------------
    // Memoria de instrucoes (128 palavras = 512 bytes).
    // -----------------------------------------------------------------
    reg [31:0] imem [0:127];

    // -----------------------------------------------------------------
    // Memoria de dados (256 palavras = 1024 bytes).
    // -----------------------------------------------------------------
    reg [31:0] dmem [0:255];

    // -----------------------------------------------------------------
    // Programa de teste (cobertura completa de instrucoes).
    // -----------------------------------------------------------------
    task load_program;
        begin
            // Test 1: Aritmetica basica
            imem[0]  = 32'h00500093; // addi x1, x0, 5       -> x1 = 5
            imem[1]  = 32'h00300113; // addi x2, x0, 3       -> x2 = 3
            imem[2]  = 32'h002081b3; // add  x3, x1, x2      -> x3 = 8
            imem[3]  = 32'h40208233; // sub  x4, x1, x2      -> x4 = 2

            // Test 2: Logicas
            imem[4]  = 32'h0020f2b3; // and  x5, x1, x2      -> x5 = 1
            imem[5]  = 32'h0020e333; // or   x6, x1, x2      -> x6 = 7
            imem[6]  = 32'h0020c3b3; // xor  x7, x1, x2      -> x7 = 6
            imem[7]  = 32'h0010f413; // andi x8, x1, 1       -> x8 = 1
            imem[8]  = 32'h0080e493; // ori  x9, x1, 8       -> x9 = 13
            imem[9]  = 32'h0050c513; // xori x10, x1, 5      -> x10 = 0

            // Test 3: Deslocamentos
            imem[10] = 32'h01000593; // addi x11, x0, 16     -> x11 = 16
            imem[11] = 32'h00259613; // slli x12, x11, 2     -> x12 = 64
            imem[12] = 32'h0025d693; // srli x13, x11, 2     -> x13 = 4
            imem[13] = 32'h00259733; // sll  x14, x11, x2    -> x14 = 128
            imem[14] = 32'h0025d7b3; // srl  x15, x11, x2    -> x15 = 4

            // Test 4: Memoria - sw depois lw
            imem[15] = 32'h06400813; // addi x16, x0, 100    -> x16 = 100
            imem[16] = 32'h01002023; // sw   x16, 0(x0)      -> mem[0] = 100
            imem[17] = 32'h00002883; // lw   x17, 0(x0)      -> x17 = 100

            // Test 5: LUI
            imem[18] = 32'h12345937; // lui  x18, 0x12345    -> x18 = 0x12345000

            // Test 6: AUIPC (PC no momento da execucao = 76)
            imem[19] = 32'h00000997; // auipc x19, 0         -> x19 = 76

            // Test 7: Branch beq tomado
            imem[20] = 32'h00318463; // beq  x3, x3, +8      -> pula para imem[22]
            imem[21] = 32'h06300a13; // addi x20, x0, 99     -> NAO executa
            imem[22] = 32'h00700a13; // addi x20, x0, 7      -> x20 = 7

            // Test 8: Branch bne nao tomado (igual)
            imem[23] = 32'h00109463; // bne  x1, x1, +8      -> nao pula (x1==x1)
            imem[24] = 32'h02a00a93; // addi x21, x0, 42     -> x21 = 42

            // Test 9: Branch bne tomado (diferente)
            imem[25] = 32'h00209463; // bne  x1, x2, +8      -> pula (5!=3)
            imem[26] = 32'h05800b13; // addi x22, x0, 88     -> NAO executa
            imem[27] = 32'h00b00b13; // addi x22, x0, 11     -> x22 = 11

            // Test 10: JAL
            imem[28] = 32'h00800bef; // jal  x23, +8         -> x23 = 116, pula para imem[30]
            imem[29] = 32'h03700c13; // addi x24, x0, 55     -> NAO executa
            imem[30] = 32'h04d00c13; // addi x24, x0, 77     -> x24 = 77

            // Test 11: JALR
            imem[31] = 32'h00000c93; // addi x25, x0, 0      -> x25 = 0
            imem[32] = 32'h00000c97; // auipc x25, 0         -> x25 = 128
            imem[33] = 32'h010c8c93; // addi x25, x25, 16    -> x25 = 144 (addr of imem[36])
            imem[34] = 32'h000c8d67; // jalr x26, x25, 0     -> x26 = 140, pula para 144
            imem[35] = 32'h04200d93; // addi x27, x0, 66     -> NAO executa
            imem[36] = 32'h02100d93; // addi x27, x0, 33     -> x27 = 33

            // Test 12: Forwarding (dependencia seguida)
            imem[37] = 32'h00a00e13; // addi x28, x0, 10     -> x28 = 10
            imem[38] = 32'h005e0e13; // addi x28, x28, 5     -> x28 = 15 (forwarding)
            imem[39] = 32'h003e0e13; // addi x28, x28, 3     -> x28 = 18 (forwarding)

            // Test 13: Load-use hazard
            imem[40] = 32'h0c800e93; // addi x29, x0, 200    -> x29 = 200
            imem[41] = 32'h01d02223; // sw   x29, 4(x0)      -> mem[1] = 200
            imem[42] = 32'h00402f03; // lw   x30, 4(x0)      -> x30 = 200
            imem[43] = 32'h001f0fb3; // add  x31, x30, x1    -> x31 = 205 (load-use stall)

            // NOPs finais para esvaziar o pipeline
            for (i = 44; i < 128; i = i + 1) begin
                imem[i] = 32'h00000013; // nop
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Espera por N ciclos de clock.
    // -----------------------------------------------------------------
    task wait_cycles;
        input integer n;
        integer c;
        begin
            for (c = 0; c < n; c = c + 1) @(posedge clk);
        end
    endtask

    // -----------------------------------------------------------------
    // Le um registrador via porta de debug e verifica o valor.
    // -----------------------------------------------------------------
    task check_reg;
        input [4:0]   addr;
        input [31:0]  expected;
        input [127:0] name;
        begin
            reg_sel = addr;
            #1;
            if (reg_debug === expected) begin
                $display("[PASS] %0s: x%0d = 0x%08h", name, addr, reg_debug);
            end else begin
                $display("[FAIL] %0s: x%0d = 0x%08h, esperado 0x%08h", name, addr, reg_debug, expected);
                errors = errors + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Clock: periodo de 10ns.
    // -----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------
    // Instancia a CPU.
    // -----------------------------------------------------------------
    riscv_cpu dut (
        .clk_i(clk),
        .reset_i(reset),
        .load_enable_i(load_enable),
        .imem_addr_o(imem_addr),
        .imem_data_i(imem_data),
        .dmem_addr_o(dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_rdata_i(dmem_rdata),
        .dmem_we_o(dmem_we),
        .pc_debug_o(pc_debug),
        .instr_debug_o(instr_debug),
        .alu_result_debug_o(alu_result_debug),
        .reg_debug_o(reg_debug),
        .reg_sel_i(reg_sel),
        .stage_if_pc_o(stage_if_pc),
        .stage_id_pc_o(stage_id_pc),
        .stage_ex_pc_o(stage_ex_pc),
        .hazard_stall_o(hazard_stall),
        .hazard_flush_o(hazard_flush),
        .alu_carry_debug_o(alu_carry_debug),
        .alu_overflow_debug_o(alu_overflow_debug)
    );

    // -----------------------------------------------------------------
    // Modelo da memoria de instrucoes (leitura combinacional).
    // -----------------------------------------------------------------
    assign imem_data = imem[imem_addr[8:2]];

    // -----------------------------------------------------------------
    // Modelo da memoria de dados (leitura combinacional, escrita sincrona).
    // -----------------------------------------------------------------
    assign dmem_rdata = dmem[dmem_addr[9:2]];

    always @(posedge clk) begin
        if (dmem_we && !load_enable) begin
            dmem[dmem_addr[9:2]] <= dmem_wdata;
        end
    end

    // -----------------------------------------------------------------
    // Dump de sinais para waveform (GTKWave).
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("tb_riscv_cpu.vcd");
        $dumpvars(0, tb_riscv_cpu);
    end

    // -----------------------------------------------------------------
    // Sequencia principal de teste.
    // -----------------------------------------------------------------
    initial begin
        errors = 0;

        // Inicializa memorias.
        load_program;
        for (i = 0; i < 256; i = i + 1) dmem[i] = 32'b0;

        // Estado inicial.
        reset = 1;
        load_enable = 0;
        reg_sel = 0;

        // Reset por 2 ciclos.
        wait_cycles(2);
        reset = 0;

        // Executa o programa (49 instrucoes + pipeline drain).
        // Cada instrucao leva ~1 ciclo no melhor caso, mais stalls/flushes.
        wait_cycles(70);

        // -----------------------------------------------------------------
        // Verificacao dos resultados.
        // -----------------------------------------------------------------
        $display("");
        $display("========================================");
        $display("  RESULTADOS DOS TESTES");
        $display("========================================");

        // Test 1: Aritmetica
        check_reg(5'd1,  32'd5,     "addi x1");
        check_reg(5'd2,  32'd3,     "addi x2");
        check_reg(5'd3,  32'd8,     "add  x3");
        check_reg(5'd4,  32'd2,     "sub  x4");

        // Test 2: Logicas
        check_reg(5'd5,  32'd1,     "and  x5");
        check_reg(5'd6,  32'd7,     "or   x6");
        check_reg(5'd7,  32'd6,     "xor  x7");
        check_reg(5'd8,  32'd1,     "andi x8");
        check_reg(5'd9,  32'd13,    "ori  x9");
        check_reg(5'd10, 32'd0,     "xori x10");

        // Test 3: Deslocamentos
        check_reg(5'd11, 32'd16,    "addi x11");
        check_reg(5'd12, 32'd64,    "slli x12");
        check_reg(5'd13, 32'd4,     "srli x13");
        check_reg(5'd14, 32'd128,   "sll  x14");
        check_reg(5'd15, 32'd2,     "srl  x15");

        // Test 4: Memoria
        check_reg(5'd16, 32'd100,   "addi x16");
        check_reg(5'd17, 32'd100,   "lw   x17");

        // Test 5: LUI
        check_reg(5'd18, 32'h12345000, "lui  x18");

        // Test 6: AUIPC (PC = 76 no momento da execucao)
        check_reg(5'd19, 32'd76,    "auipc x19");

        // Test 7: Branch beq tomado
        check_reg(5'd20, 32'd7,     "beq  x20");

        // Test 8: Branch bne nao tomado
        check_reg(5'd21, 32'd42,    "bne  x21");

        // Test 9: Branch bne tomado
        check_reg(5'd22, 32'd11,    "bne  x22");

        // Test 10: JAL
        check_reg(5'd23, 32'd116,   "jal  x23 (ret addr)");
        check_reg(5'd24, 32'd77,    "jal  x24");

        // Test 11: JALR
        check_reg(5'd26, 32'd140,   "jalr x26 (ret addr)");
        check_reg(5'd27, 32'd33,    "jalr x27");

        // Test 12: Forwarding
        check_reg(5'd28, 32'd18,    "forwarding x28");

        // Test 13: Load-use hazard
        check_reg(5'd29, 32'd200,   "sw/lw x29");
        check_reg(5'd30, 32'd200,   "lw   x30");
        check_reg(5'd31, 32'd205,   "load-use x31");

        // Verifica memoria de dados
        if (dmem[0] === 32'd100) begin
            $display("[PASS] mem[0] = 0x%08h (sw x16)", dmem[0]);
        end else begin
            $display("[FAIL] mem[0] = 0x%08h, esperado 0x00000064", dmem[0]);
            errors = errors + 1;
        end

        if (dmem[1] === 32'd200) begin
            $display("[PASS] mem[1] = 0x%08h (sw x29)", dmem[1]);
        end else begin
            $display("[FAIL] mem[1] = 0x%08h, esperado 0x000000c8", dmem[1]);
            errors = errors + 1;
        end

        $display("========================================");
        if (errors == 0) begin
            $display("  TODOS OS TESTES PASSARAM (0 erros)");
        end else begin
            $display("  FALHA: %0d erro(s) encontrado(s)", errors);
        end
        $display("========================================");
        $display("");

        $finish;
    end

endmodule
