// =============================================================================
// Arquivo combinado para uso no simulador Digital.
// riscv_cpu DEVE ser o primeiro modulo para o Digital seleciona-lo como top-level.
// =============================================================================

// =============================================================================
// Top-level da CPU RISC-V RV32I com pipeline de 5 estagios.
// Integra fetch, decode, execute, memoria e write-back com debug e hazards.
// =============================================================================

module riscv_cpu (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        load_enable_i,
    output wire [31:0] imem_addr_o,
    input  wire [31:0] imem_data_i,
    output wire [31:0] dmem_addr_o,
    output wire [31:0] dmem_wdata_o,
    input  wire [31:0] dmem_rdata_i,
    output wire        dmem_we_o,
    output wire [31:0] pc_debug_o,
    output wire [31:0] instr_debug_o,
    output wire [31:0] alu_result_debug_o,
    output wire [31:0] reg_debug_o,
    input  wire [4:0]  reg_sel_i,
    output wire [31:0] stage_if_pc_o,
    output wire [31:0] stage_id_pc_o,
    output wire [31:0] stage_ex_pc_o,
    output wire        hazard_stall_o,
    output wire        hazard_flush_o,
    output wire        alu_carry_debug_o,
    output wire        alu_overflow_debug_o
);

    // -------------------------------------------------------------------------
    // Sinais do estagio IF.
    // -------------------------------------------------------------------------
    wire [31:0] if_pc;
    wire [31:0] if_pc_plus4;
    wire [31:0] if_instruction;

    // -------------------------------------------------------------------------
    // Sinais do IF/ID.
    // -------------------------------------------------------------------------
    wire [31:0] id_pc;
    wire [31:0] id_pc_plus4;
    wire [31:0] id_instruction;

    // -------------------------------------------------------------------------
    // Sinais do estagio ID.
    // -------------------------------------------------------------------------
    wire [6:0]  id_opcode;
    wire [4:0]  id_rd;
    wire [2:0]  id_funct3;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [6:0]  id_funct7;
    wire [31:0] id_imm;
    wire [2:0]  id_instr_type;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_rs1_final;
    wire [31:0] id_rs2_final;
    wire        id_reg_write;
    wire        id_mem_to_reg;
    wire        id_mem_write;
    wire        id_mem_read;
    wire        id_alu_src;
    wire [3:0]  id_alu_ctrl;
    wire        id_branch;
    wire        id_jump;
    wire        id_auipc;
    wire        id_jalr;
    wire        id_lui;

    // -------------------------------------------------------------------------
    // Sinais do ID/EX.
    // -------------------------------------------------------------------------
    wire [31:0] ex_pc;
    wire [31:0] ex_pc_plus4;
    wire [31:0] ex_rs1_data;
    wire [31:0] ex_rs2_data;
    wire [31:0] ex_imm;
    wire [4:0]  ex_rs1_addr;
    wire [4:0]  ex_rs2_addr;
    wire [4:0]  ex_rd_addr;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write;
    wire        ex_mem_to_reg;
    wire        ex_mem_write;
    wire        ex_mem_read;
    wire        ex_alu_src;
    wire [3:0]  ex_alu_ctrl;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_auipc;
    wire        ex_jalr;
    wire        ex_lui;

    // -------------------------------------------------------------------------
    // Sinais do estagio EX.
    // -------------------------------------------------------------------------
    reg  [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;
    wire        ex_alu_carry;
    wire        ex_alu_overflow;
    wire        ex_branch_taken;
    reg  [31:0] ex_target_addr;
    wire [1:0]  ex_forward_a;
    wire [1:0]  ex_forward_b;
    reg  [31:0] ex_rs1_forwarded;
    reg  [31:0] ex_rs2_forwarded;

    // -------------------------------------------------------------------------
    // Sinais do EX/MEM.
    // -------------------------------------------------------------------------
    wire [31:0] mem_pc_plus4;
    wire [31:0] mem_alu_result;
    wire [31:0] mem_rs2_data;
    wire [4:0]  mem_rd_addr;
    wire        mem_zero;
    wire        mem_reg_write;
    wire        mem_mem_to_reg;
    wire        mem_mem_write;
    wire        mem_mem_read;
    wire        mem_branch;
    wire        mem_jump;

    // -------------------------------------------------------------------------
    // Sinais do estagio MEM.
    // -------------------------------------------------------------------------
    wire [31:0] mem_read_data;

    // -------------------------------------------------------------------------
    // Sinais do MEM/WB.
    // -------------------------------------------------------------------------
    wire [31:0] wb_pc_plus4;
    wire [31:0] wb_alu_result;
    wire [31:0] wb_mem_data;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;
    wire        wb_mem_to_reg;
    wire        wb_jump;

    // -------------------------------------------------------------------------
    // Sinais do estagio WB.
    // -------------------------------------------------------------------------
    reg [31:0] wb_write_data;

    // -------------------------------------------------------------------------
    // Controle de hazards.
    // -------------------------------------------------------------------------
    wire       stall_if;
    wire       stall_id;
    wire       flush_id;
    wire       flush_ex;
    wire [1:0] hazard_type;

    // -------------------------------------------------------------------------
    // Estagio IF.
    // -------------------------------------------------------------------------
    program_counter u_pc (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .stall_i(stall_if),
        .load_enable_i(load_enable_i),
        .branch_taken_i(ex_branch_taken),
        .jump_i(ex_jump),
        .target_addr_i(ex_target_addr),
        .pc_o(if_pc),
        .pc_plus4_o(if_pc_plus4)
    );

    assign imem_addr_o    = if_pc;
    assign if_instruction = imem_data_i;

    if_id_reg u_if_id (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .stall_i(stall_id),
        .flush_i(flush_id),
        .load_enable_i(load_enable_i),
        .pc_i(if_pc),
        .pc_plus4_i(if_pc_plus4),
        .instruction_i(if_instruction),
        .pc_o(id_pc),
        .pc_plus4_o(id_pc_plus4),
        .instruction_o(id_instruction)
    );

    // -------------------------------------------------------------------------
    // Estagio ID.
    // -------------------------------------------------------------------------
    instruction_decoder u_decoder (
        .instruction_i(id_instruction),
        .opcode_o(id_opcode),
        .rd_o(id_rd),
        .funct3_o(id_funct3),
        .rs1_o(id_rs1),
        .rs2_o(id_rs2),
        .funct7_o(id_funct7),
        .imm_o(id_imm),
        .instr_type_o(id_instr_type)
    );

    control_unit u_control (
        .opcode_i(id_opcode),
        .funct3_i(id_funct3),
        .funct7_i(id_funct7),
        .reg_write_o(id_reg_write),
        .mem_to_reg_o(id_mem_to_reg),
        .mem_write_o(id_mem_write),
        .mem_read_o(id_mem_read),
        .alu_src_o(id_alu_src),
        .alu_ctrl_o(id_alu_ctrl),
        .branch_o(id_branch),
        .jump_o(id_jump),
        .auipc_o(id_auipc),
        .jalr_o(id_jalr),
        .lui_o(id_lui)
    );

    register_file u_regfile (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .we_i(wb_reg_write),
        .rs1_addr_i(id_rs1),
        .rs2_addr_i(id_rs2),
        .rd_addr_i(wb_rd_addr),
        .rd_data_i(wb_write_data),
        .rs1_data_o(id_rs1_data),
        .rs2_data_o(id_rs2_data),
        .reg_debug_o(reg_debug_o),
        .reg_sel_i(reg_sel_i)
    );

    // Internal forwarding: WB -> ID.
    // Quando o estagio WB esta escrevendo em um registrador que o estagio ID
    // esta lendo, a escrita sincrona (NBA) ainda nao aconteceu no momento em
    // que o id_ex_reg captura o dado. Este mux resolve o conflito
    // write-before-read usando o dado do WB diretamente.
    assign id_rs1_final = (wb_reg_write && (wb_rd_addr != 5'b00000) &&
                           (wb_rd_addr == id_rs1)) ? wb_write_data : id_rs1_data;
    assign id_rs2_final = (wb_reg_write && (wb_rd_addr != 5'b00000) &&
                           (wb_rd_addr == id_rs2)) ? wb_write_data : id_rs2_data;

    id_ex_reg u_id_ex (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .stall_i(1'b0),
        .flush_i(flush_ex),
        .load_enable_i(load_enable_i),
        .pc_i(id_pc),
        .pc_plus4_i(id_pc_plus4),
        .rs1_data_i(id_rs1_final),
        .rs2_data_i(id_rs2_final),
        .imm_i(id_imm),
        .rs1_addr_i(id_rs1),
        .rs2_addr_i(id_rs2),
        .rd_addr_i(id_rd),
        .funct3_i(id_funct3),
        .reg_write_i(id_reg_write),
        .mem_to_reg_i(id_mem_to_reg),
        .mem_write_i(id_mem_write),
        .mem_read_i(id_mem_read),
        .alu_src_i(id_alu_src),
        .alu_ctrl_i(id_alu_ctrl),
        .branch_i(id_branch),
        .jump_i(id_jump),
        .auipc_i(id_auipc),
        .jalr_i(id_jalr),
        .lui_i(id_lui),
        .pc_o(ex_pc),
        .pc_plus4_o(ex_pc_plus4),
        .rs1_data_o(ex_rs1_data),
        .rs2_data_o(ex_rs2_data),
        .imm_o(ex_imm),
        .rs1_addr_o(ex_rs1_addr),
        .rs2_addr_o(ex_rs2_addr),
        .rd_addr_o(ex_rd_addr),
        .funct3_o(ex_funct3),
        .reg_write_o(ex_reg_write),
        .mem_to_reg_o(ex_mem_to_reg),
        .mem_write_o(ex_mem_write),
        .mem_read_o(ex_mem_read),
        .alu_src_o(ex_alu_src),
        .alu_ctrl_o(ex_alu_ctrl),
        .branch_o(ex_branch),
        .jump_o(ex_jump),
        .auipc_o(ex_auipc),
        .jalr_o(ex_jalr),
        .lui_o(ex_lui)
    );

    // -------------------------------------------------------------------------
    // Estagio EX.
    // -------------------------------------------------------------------------
    forwarding_unit u_forwarding (
        .rs1_ex_i(ex_rs1_addr),
        .rs2_ex_i(ex_rs2_addr),
        .rd_mem_i(mem_rd_addr),
        .reg_write_mem_i(mem_reg_write),
        .rd_wb_i(wb_rd_addr),
        .reg_write_wb_i(wb_reg_write),
        .forward_a_o(ex_forward_a),
        .forward_b_o(ex_forward_b)
    );

    // Multiplexa forwarding para o operando A.
    always @(*) begin
        case (ex_forward_a)
            2'b01: ex_rs1_forwarded = mem_alu_result;
            2'b10: ex_rs1_forwarded = wb_write_data;
            default: ex_rs1_forwarded = ex_rs1_data;
        endcase
    end

    // Multiplexa forwarding para o operando B.
    always @(*) begin
        case (ex_forward_b)
            2'b01: ex_rs2_forwarded = mem_alu_result;
            2'b10: ex_rs2_forwarded = wb_write_data;
            default: ex_rs2_forwarded = ex_rs2_data;
        endcase
    end

    // Seleciona a entrada A da ALU para rs1, PC ou zero.
    always @(*) begin
        if (ex_auipc) begin
            ex_alu_a = ex_pc;
        end else if (ex_lui) begin
            ex_alu_a = 32'b0;
        end else begin
            ex_alu_a = ex_rs1_forwarded;
        end
    end

    assign ex_alu_b = ex_alu_src ? ex_imm : ex_rs2_forwarded;

    alu u_alu (
        .a_i(ex_alu_a),
        .b_i(ex_alu_b),
        .alu_ctrl_i(ex_alu_ctrl),
        .result_o(ex_alu_result),
        .zero_o(ex_alu_zero),
        .carry_o(ex_alu_carry),
        .overflow_o(ex_alu_overflow)
    );

    branch_comparator u_branch_cmp (
        .a_i(ex_rs1_forwarded),
        .b_i(ex_rs2_forwarded),
        .funct3_i(ex_funct3),
        .branch_i(ex_branch),
        .branch_taken_o(ex_branch_taken),
        .eq_o(),
        .ne_o()
    );

    // Calcula o alvo de branch/jump no EX.
    always @(*) begin
        if (ex_jalr) begin
            ex_target_addr    = ex_rs1_forwarded + ex_imm;
            ex_target_addr[0] = 1'b0;
        end else begin
            ex_target_addr = ex_pc + ex_imm;
        end
    end

    hazard_unit u_hazard (
        .rs1_id_i(id_rs1),
        .rs2_id_i(id_rs2),
        .rd_ex_i(ex_rd_addr),
        .mem_read_ex_i(ex_mem_read),
        .branch_taken_i(ex_branch_taken),
        .jump_i(ex_jump),
        .stall_if_o(stall_if),
        .stall_id_o(stall_id),
        .flush_id_o(flush_id),
        .flush_ex_o(flush_ex),
        .hazard_type_o(hazard_type)
    );

    ex_mem_reg u_ex_mem (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .flush_i(1'b0),
        .load_enable_i(load_enable_i),
        .pc_plus4_i(ex_pc_plus4),
        .alu_result_i(ex_alu_result),
        .rs2_data_i(ex_rs2_forwarded),
        .rd_addr_i(ex_rd_addr),
        .zero_i(ex_alu_zero),
        .reg_write_i(ex_reg_write),
        .mem_to_reg_i(ex_mem_to_reg),
        .mem_write_i(ex_mem_write),
        .mem_read_i(ex_mem_read),
        .branch_i(ex_branch),
        .jump_i(ex_jump),
        .pc_plus4_o(mem_pc_plus4),
        .alu_result_o(mem_alu_result),
        .rs2_data_o(mem_rs2_data),
        .rd_addr_o(mem_rd_addr),
        .zero_o(mem_zero),
        .reg_write_o(mem_reg_write),
        .mem_to_reg_o(mem_mem_to_reg),
        .mem_write_o(mem_mem_write),
        .mem_read_o(mem_mem_read),
        .branch_o(mem_branch),
        .jump_o(mem_jump)
    );

    // -------------------------------------------------------------------------
    // Estagio MEM.
    // -------------------------------------------------------------------------
    assign dmem_addr_o  = mem_alu_result;
    assign dmem_wdata_o = mem_rs2_data;
    assign dmem_we_o    = mem_mem_write & ~load_enable_i;
    assign mem_read_data = dmem_rdata_i;

    mem_wb_reg u_mem_wb (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .load_enable_i(load_enable_i),
        .pc_plus4_i(mem_pc_plus4),
        .alu_result_i(mem_alu_result),
        .mem_data_i(mem_read_data),
        .rd_addr_i(mem_rd_addr),
        .reg_write_i(mem_reg_write),
        .mem_to_reg_i(mem_mem_to_reg),
        .jump_i(mem_jump),
        .pc_plus4_o(wb_pc_plus4),
        .alu_result_o(wb_alu_result),
        .mem_data_o(wb_mem_data),
        .rd_addr_o(wb_rd_addr),
        .reg_write_o(wb_reg_write),
        .mem_to_reg_o(wb_mem_to_reg),
        .jump_o(wb_jump)
    );

    // -------------------------------------------------------------------------
    // Estagio WB.
    // -------------------------------------------------------------------------
    always @(*) begin
        if (wb_jump) begin
            wb_write_data = wb_pc_plus4;
        end else if (wb_mem_to_reg) begin
            wb_write_data = wb_mem_data;
        end else begin
            wb_write_data = wb_alu_result;
        end
    end

    // -------------------------------------------------------------------------
    // Saidas de debug.
    // -------------------------------------------------------------------------
    assign pc_debug_o         = if_pc;
    assign instr_debug_o      = id_instruction;
    assign alu_result_debug_o = ex_alu_result;
    assign stage_if_pc_o      = if_pc;
    assign stage_id_pc_o      = id_pc;
    assign stage_ex_pc_o      = ex_pc;
    assign hazard_stall_o     = stall_if | stall_id;
    assign hazard_flush_o     = flush_id | flush_ex;
    assign alu_carry_debug_o    = ex_alu_carry;
    assign alu_overflow_debug_o = ex_alu_overflow;

endmodule
// =============================================================================
// ALU escalar para a CPU RISC-V RV32I.
// Implementa as operacoes inteiras exigidas pelo PDF e expoe sinais de debug.
// =============================================================================

module alu (
    input  wire [31:0] a_i,
    input  wire [31:0] b_i,
    input  wire [3:0]  alu_ctrl_i,
    output reg  [31:0] result_o,
    output wire        zero_o,
    output wire        carry_o,
    output wire        overflow_o
);

    // Codigos de operacao da ALU.
    localparam [3:0] ALU_ADD    = 4'b0000;
    localparam [3:0] ALU_SUB    = 4'b0001;
    localparam [3:0] ALU_AND    = 4'b0010;
    localparam [3:0] ALU_OR     = 4'b0011;
    localparam [3:0] ALU_XOR    = 4'b0100;
    localparam [3:0] ALU_SLL    = 4'b0101;
    localparam [3:0] ALU_SRL    = 4'b0110;
    localparam [3:0] ALU_PASS_B = 4'b0111;

    // Barramentos estendidos para aferir carry/borrow sem perder o bit extra.
    wire [32:0] add_result = {1'b0, a_i} + {1'b0, b_i};
    wire [32:0] sub_result = {1'b0, a_i} - {1'b0, b_i};
    wire [4:0]  shamt      = b_i[4:0];

    // Bloco combinacional principal da ALU.
    always @(*) begin
        case (alu_ctrl_i)
            ALU_ADD:    result_o = add_result[31:0];
            ALU_SUB:    result_o = sub_result[31:0];
            ALU_AND:    result_o = a_i & b_i;
            ALU_OR:     result_o = a_i | b_i;
            ALU_XOR:    result_o = a_i ^ b_i;
            ALU_SLL:    result_o = a_i << shamt;
            ALU_SRL:    result_o = a_i >> shamt;
            ALU_PASS_B: result_o = b_i;
            default:    result_o = 32'b0;
        endcase
    end

    // Flags uteis para branch e para depuracao.
    assign zero_o     = (result_o == 32'b0);
    assign carry_o    = (alu_ctrl_i == ALU_ADD) ? add_result[32] : 1'b0;
    assign overflow_o = (alu_ctrl_i == ALU_ADD)
                      ? ((~a_i[31] & ~b_i[31] &  result_o[31]) |
                         ( a_i[31] &  b_i[31] & ~result_o[31]))
                      : 1'b0;

endmodule
// =============================================================================
// Comparador de branch para as instrucoes beq e bne.
// Mantem sinais de debug separados para igualdade e desigualdade.
// =============================================================================

module branch_comparator (
    input  wire [31:0] a_i,
    input  wire [31:0] b_i,
    input  wire [2:0]  funct3_i,
    input  wire        branch_i,
    output reg         branch_taken_o,
    output wire        eq_o,
    output wire        ne_o
);

    localparam [2:0] FUNCT3_BEQ = 3'b000;
    localparam [2:0] FUNCT3_BNE = 3'b001;

    assign eq_o = (a_i == b_i);
    assign ne_o = ~eq_o;

    // Decide o desvio apenas quando a instrucao corrente e de branch.
    always @(*) begin
        branch_taken_o = 1'b0;

        if (branch_i) begin
            case (funct3_i)
                FUNCT3_BEQ: branch_taken_o = eq_o;
                FUNCT3_BNE: branch_taken_o = ne_o;
                default:    branch_taken_o = 1'b0;
            endcase
        end
    end

endmodule
// =============================================================================
// Unidade de controle principal da CPU basica RV32I.
// Gera apenas os sinais escalares exigidos pelo primeiro projeto.
// =============================================================================

module control_unit (
    input  wire [6:0] opcode_i,
    input  wire [2:0] funct3_i,
    input  wire [6:0] funct7_i,
    output reg        reg_write_o,
    output reg        mem_to_reg_o,
    output reg        mem_write_o,
    output reg        mem_read_o,
    output reg        alu_src_o,
    output reg  [3:0] alu_ctrl_o,
    output reg        branch_o,
    output reg        jump_o,
    output reg        auipc_o,
    output reg        jalr_o,
    output reg        lui_o
);

    // Opcodes escalares RV32I.
    localparam [6:0] OP_R_TYPE = 7'b0110011;
    localparam [6:0] OP_I_TYPE = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_AUIPC  = 7'b0010111;

    // Operacoes da ALU.
    localparam [3:0] ALU_ADD    = 4'b0000;
    localparam [3:0] ALU_SUB    = 4'b0001;
    localparam [3:0] ALU_AND    = 4'b0010;
    localparam [3:0] ALU_OR     = 4'b0011;
    localparam [3:0] ALU_XOR    = 4'b0100;
    localparam [3:0] ALU_SLL    = 4'b0101;
    localparam [3:0] ALU_SRL    = 4'b0110;
    localparam [3:0] ALU_PASS_B = 4'b0111;

    reg [3:0] alu_ctrl_r_type;
    reg [3:0] alu_ctrl_i_type;

    // Decodificacao das instrucoes R-type escalares.
    always @(*) begin
        case (funct3_i)
            3'b000: alu_ctrl_r_type = (funct7_i == 7'b0100000) ? ALU_SUB : ALU_ADD;
            3'b111: alu_ctrl_r_type = ALU_AND;
            3'b110: alu_ctrl_r_type = ALU_OR;
            3'b100: alu_ctrl_r_type = ALU_XOR;
            3'b001: alu_ctrl_r_type = ALU_SLL;
            3'b101: alu_ctrl_r_type = ALU_SRL;
            default: alu_ctrl_r_type = ALU_ADD;
        endcase
    end

    // Decodificacao das instrucoes I-type escalares.
    always @(*) begin
        case (funct3_i)
            3'b000: alu_ctrl_i_type = ALU_ADD;
            3'b111: alu_ctrl_i_type = ALU_AND;
            3'b110: alu_ctrl_i_type = ALU_OR;
            3'b100: alu_ctrl_i_type = ALU_XOR;
            3'b001: alu_ctrl_i_type = ALU_SLL;
            3'b101: alu_ctrl_i_type = ALU_SRL;
            default: alu_ctrl_i_type = ALU_ADD;
        endcase
    end

    // Bloco central da unidade de controle.
    always @(*) begin
        // Defaults equivalentes a um NOP.
        reg_write_o  = 1'b0;
        mem_to_reg_o = 1'b0;
        mem_write_o  = 1'b0;
        mem_read_o   = 1'b0;
        alu_src_o    = 1'b0;
        alu_ctrl_o   = ALU_ADD;
        branch_o     = 1'b0;
        jump_o       = 1'b0;
        auipc_o      = 1'b0;
        jalr_o       = 1'b0;
        lui_o        = 1'b0;

        case (opcode_i)
            OP_R_TYPE: begin
                reg_write_o = 1'b1;
                alu_ctrl_o  = alu_ctrl_r_type;
            end

            OP_I_TYPE: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1;
                alu_ctrl_o  = alu_ctrl_i_type;
            end

            OP_LOAD: begin
                reg_write_o  = 1'b1;
                mem_to_reg_o = 1'b1;
                mem_read_o   = 1'b1;
                alu_src_o    = 1'b1;
                alu_ctrl_o   = ALU_ADD;
            end

            OP_STORE: begin
                mem_write_o = 1'b1;
                alu_src_o   = 1'b1;
                alu_ctrl_o  = ALU_ADD;
            end

            OP_BRANCH: begin
                branch_o   = 1'b1;
                alu_ctrl_o = ALU_SUB;
            end

            OP_JAL: begin
                reg_write_o = 1'b1;
                jump_o      = 1'b1;
            end

            OP_JALR: begin
                reg_write_o = 1'b1;
                jump_o      = 1'b1;
                jalr_o      = 1'b1;
                alu_src_o   = 1'b1;
            end

            OP_LUI: begin
                reg_write_o = 1'b1;
                lui_o       = 1'b1;
                alu_src_o   = 1'b1;
                alu_ctrl_o  = ALU_PASS_B;
            end

            OP_AUIPC: begin
                reg_write_o = 1'b1;
                auipc_o     = 1'b1;
                alu_src_o   = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule
// =============================================================================
// Unidade de forwarding escalar.
// Resolve dependencias RAW entre EX/MEM e MEM/WB com prioridade para MEM.
// =============================================================================

module forwarding_unit (
    input  wire [4:0] rs1_ex_i,
    input  wire [4:0] rs2_ex_i,
    input  wire [4:0] rd_mem_i,
    input  wire       reg_write_mem_i,
    input  wire [4:0] rd_wb_i,
    input  wire       reg_write_wb_i,
    output reg  [1:0] forward_a_o,
    output reg  [1:0] forward_b_o
);

    // Seleciona a origem do operando A no EX.
    always @(*) begin
        if (reg_write_mem_i && (rd_mem_i != 5'b00000) && (rd_mem_i == rs1_ex_i)) begin
            forward_a_o = 2'b01;
        end else if (reg_write_wb_i && (rd_wb_i != 5'b00000) && (rd_wb_i == rs1_ex_i)) begin
            forward_a_o = 2'b10;
        end else begin
            forward_a_o = 2'b00;
        end
    end

    // Seleciona a origem do operando B no EX.
    always @(*) begin
        if (reg_write_mem_i && (rd_mem_i != 5'b00000) && (rd_mem_i == rs2_ex_i)) begin
            forward_b_o = 2'b01;
        end else if (reg_write_wb_i && (rd_wb_i != 5'b00000) && (rd_wb_i == rs2_ex_i)) begin
            forward_b_o = 2'b10;
        end else begin
            forward_b_o = 2'b00;
        end
    end

endmodule
// =============================================================================
// Unidade de deteccao de hazards.
// Trata hazards de load-use e hazards de controle oriundos de branch/jump.
// =============================================================================

module hazard_unit (
    input  wire [4:0] rs1_id_i,
    input  wire [4:0] rs2_id_i,
    input  wire [4:0] rd_ex_i,
    input  wire       mem_read_ex_i,
    input  wire       branch_taken_i,
    input  wire       jump_i,
    output reg        stall_if_o,
    output reg        stall_id_o,
    output reg        flush_id_o,
    output reg        flush_ex_o,
    output reg  [1:0] hazard_type_o
);

    wire load_use_hazard = mem_read_ex_i &&
                           (rd_ex_i != 5'b00000) &&
                           ((rd_ex_i == rs1_id_i) || (rd_ex_i == rs2_id_i));

    wire control_hazard = branch_taken_i || jump_i;

    // Gera stall/flush preservando prioridade do hazard de controle.
    always @(*) begin
        stall_if_o    = 1'b0;
        stall_id_o    = 1'b0;
        flush_id_o    = 1'b0;
        flush_ex_o    = 1'b0;
        hazard_type_o = 2'b00;

        if (load_use_hazard) begin
            stall_if_o    = 1'b1;
            stall_id_o    = 1'b1;
            flush_ex_o    = 1'b1;
            hazard_type_o = 2'b01;
        end

        if (control_hazard) begin
            flush_id_o    = 1'b1;
            flush_ex_o    = 1'b1;
            hazard_type_o = 2'b10;
        end
    end

endmodule
// =============================================================================
// Decoder + gerador de imediatos da CPU basica.
// Extrai campos da instrucao e produz imediatos para formatos R/I/S/B/U/J.
// =============================================================================

module instruction_decoder (
    input  wire [31:0] instruction_i,
    output wire [6:0]  opcode_o,
    output wire [4:0]  rd_o,
    output wire [2:0]  funct3_o,
    output wire [4:0]  rs1_o,
    output wire [4:0]  rs2_o,
    output wire [6:0]  funct7_o,
    output reg  [31:0] imm_o,
    output reg  [2:0]  instr_type_o
);

    localparam [6:0] OP_R_TYPE = 7'b0110011;
    localparam [6:0] OP_I_TYPE = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JAL    = 7'b1101111;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [2:0] TYPE_R = 3'b000;
    localparam [2:0] TYPE_I = 3'b001;
    localparam [2:0] TYPE_S = 3'b010;
    localparam [2:0] TYPE_B = 3'b011;
    localparam [2:0] TYPE_U = 3'b100;
    localparam [2:0] TYPE_J = 3'b101;

    wire [6:0] opcode_internal = instruction_i[6:0];
    wire [31:0] imm_i_type = {{20{instruction_i[31]}}, instruction_i[31:20]};
    wire [31:0] imm_s_type = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
    wire [31:0] imm_b_type = {{19{instruction_i[31]}}, instruction_i[31], instruction_i[7],
                              instruction_i[30:25], instruction_i[11:8], 1'b0};
    wire [31:0] imm_u_type = {instruction_i[31:12], 12'b0};
    wire [31:0] imm_j_type = {{11{instruction_i[31]}}, instruction_i[31], instruction_i[19:12],
                              instruction_i[20], instruction_i[30:21], 1'b0};

    assign opcode_o = opcode_internal;
    assign rd_o     = instruction_i[11:7];
    assign funct3_o = instruction_i[14:12];
    assign rs1_o    = instruction_i[19:15];
    assign rs2_o    = instruction_i[24:20];
    assign funct7_o = instruction_i[31:25];

    // Seleciona o imediato correto para cada classe de instrucao.
    always @(*) begin
        imm_o        = 32'b0;
        instr_type_o = 3'b111;

        case (opcode_internal)
            OP_R_TYPE: begin
                imm_o        = 32'b0;
                instr_type_o = TYPE_R;
            end

            OP_I_TYPE,
            OP_LOAD,
            OP_JALR: begin
                imm_o        = imm_i_type;
                instr_type_o = TYPE_I;
            end

            OP_STORE: begin
                imm_o        = imm_s_type;
                instr_type_o = TYPE_S;
            end

            OP_BRANCH: begin
                imm_o        = imm_b_type;
                instr_type_o = TYPE_B;
            end

            OP_LUI,
            OP_AUIPC: begin
                imm_o        = imm_u_type;
                instr_type_o = TYPE_U;
            end

            OP_JAL: begin
                imm_o        = imm_j_type;
                instr_type_o = TYPE_J;
            end

            default: begin
            end
        endcase
    end

endmodule
// =============================================================================
// Registradores de pipeline escalares para a CPU de 5 estagios.
// Inclui IF/ID, ID/EX, EX/MEM e MEM/WB com suporte a stall/flush e pausa.
// =============================================================================

module if_id_reg (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        stall_i,
    input  wire        flush_i,
    input  wire        load_enable_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] pc_plus4_i,
    input  wire [31:0] instruction_i,
    output reg  [31:0] pc_o,
    output reg  [31:0] pc_plus4_o,
    output reg  [31:0] instruction_o
);

    localparam [31:0] NOP_INSTR = 32'h00000013;

    // Armazena o estado entre IF e ID.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pc_o          <= 32'b0;
            pc_plus4_o    <= 32'b0;
            instruction_o <= 32'b0;
        end else if (!load_enable_i) begin
            if (flush_i) begin
                pc_o          <= 32'b0;
                pc_plus4_o    <= 32'b0;
                instruction_o <= NOP_INSTR;
            end else if (!stall_i) begin
                pc_o          <= pc_i;
                pc_plus4_o    <= pc_plus4_i;
                instruction_o <= instruction_i;
            end
        end
    end

endmodule

module id_ex_reg (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        stall_i,
    input  wire        flush_i,
    input  wire        load_enable_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] pc_plus4_i,
    input  wire [31:0] rs1_data_i,
    input  wire [31:0] rs2_data_i,
    input  wire [31:0] imm_i,
    input  wire [4:0]  rs1_addr_i,
    input  wire [4:0]  rs2_addr_i,
    input  wire [4:0]  rd_addr_i,
    input  wire [2:0]  funct3_i,
    input  wire        reg_write_i,
    input  wire        mem_to_reg_i,
    input  wire        mem_write_i,
    input  wire        mem_read_i,
    input  wire        alu_src_i,
    input  wire [3:0]  alu_ctrl_i,
    input  wire        branch_i,
    input  wire        jump_i,
    input  wire        auipc_i,
    input  wire        jalr_i,
    input  wire        lui_i,
    output reg  [31:0] pc_o,
    output reg  [31:0] pc_plus4_o,
    output reg  [31:0] rs1_data_o,
    output reg  [31:0] rs2_data_o,
    output reg  [31:0] imm_o,
    output reg  [4:0]  rs1_addr_o,
    output reg  [4:0]  rs2_addr_o,
    output reg  [4:0]  rd_addr_o,
    output reg  [2:0]  funct3_o,
    output reg         reg_write_o,
    output reg         mem_to_reg_o,
    output reg         mem_write_o,
    output reg         mem_read_o,
    output reg         alu_src_o,
    output reg  [3:0]  alu_ctrl_o,
    output reg         branch_o,
    output reg         jump_o,
    output reg         auipc_o,
    output reg         jalr_o,
    output reg         lui_o
);

    // Propaga dados/controle do decode para execute.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pc_o         <= 32'b0;
            pc_plus4_o   <= 32'b0;
            rs1_data_o   <= 32'b0;
            rs2_data_o   <= 32'b0;
            imm_o        <= 32'b0;
            rs1_addr_o   <= 5'b0;
            rs2_addr_o   <= 5'b0;
            rd_addr_o    <= 5'b0;
            funct3_o     <= 3'b0;
            reg_write_o  <= 1'b0;
            mem_to_reg_o <= 1'b0;
            mem_write_o  <= 1'b0;
            mem_read_o   <= 1'b0;
            alu_src_o    <= 1'b0;
            alu_ctrl_o   <= 4'b0;
            branch_o     <= 1'b0;
            jump_o       <= 1'b0;
            auipc_o      <= 1'b0;
            jalr_o       <= 1'b0;
            lui_o        <= 1'b0;
        end else if (!load_enable_i) begin
            if (flush_i) begin
                pc_o         <= 32'b0;
                pc_plus4_o   <= 32'b0;
                rs1_data_o   <= 32'b0;
                rs2_data_o   <= 32'b0;
                imm_o        <= 32'b0;
                rs1_addr_o   <= 5'b0;
                rs2_addr_o   <= 5'b0;
                rd_addr_o    <= 5'b0;
                funct3_o     <= 3'b0;
                reg_write_o  <= 1'b0;
                mem_to_reg_o <= 1'b0;
                mem_write_o  <= 1'b0;
                mem_read_o   <= 1'b0;
                alu_src_o    <= 1'b0;
                alu_ctrl_o   <= 4'b0;
                branch_o     <= 1'b0;
                jump_o       <= 1'b0;
                auipc_o      <= 1'b0;
                jalr_o       <= 1'b0;
                lui_o        <= 1'b0;
            end else if (!stall_i) begin
                pc_o         <= pc_i;
                pc_plus4_o   <= pc_plus4_i;
                rs1_data_o   <= rs1_data_i;
                rs2_data_o   <= rs2_data_i;
                imm_o        <= imm_i;
                rs1_addr_o   <= rs1_addr_i;
                rs2_addr_o   <= rs2_addr_i;
                rd_addr_o    <= rd_addr_i;
                funct3_o     <= funct3_i;
                reg_write_o  <= reg_write_i;
                mem_to_reg_o <= mem_to_reg_i;
                mem_write_o  <= mem_write_i;
                mem_read_o   <= mem_read_i;
                alu_src_o    <= alu_src_i;
                alu_ctrl_o   <= alu_ctrl_i;
                branch_o     <= branch_i;
                jump_o       <= jump_i;
                auipc_o      <= auipc_i;
                jalr_o       <= jalr_i;
                lui_o        <= lui_i;
            end
        end
    end

endmodule

module ex_mem_reg (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        flush_i,
    input  wire        load_enable_i,
    input  wire [31:0] pc_plus4_i,
    input  wire [31:0] alu_result_i,
    input  wire [31:0] rs2_data_i,
    input  wire [4:0]  rd_addr_i,
    input  wire        zero_i,
    input  wire        reg_write_i,
    input  wire        mem_to_reg_i,
    input  wire        mem_write_i,
    input  wire        mem_read_i,
    input  wire        branch_i,
    input  wire        jump_i,
    output reg  [31:0] pc_plus4_o,
    output reg  [31:0] alu_result_o,
    output reg  [31:0] rs2_data_o,
    output reg  [4:0]  rd_addr_o,
    output reg         zero_o,
    output reg         reg_write_o,
    output reg         mem_to_reg_o,
    output reg         mem_write_o,
    output reg         mem_read_o,
    output reg         branch_o,
    output reg         jump_o
);

    // Propaga o resultado do EX para MEM.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pc_plus4_o   <= 32'b0;
            alu_result_o <= 32'b0;
            rs2_data_o   <= 32'b0;
            rd_addr_o    <= 5'b0;
            zero_o       <= 1'b0;
            reg_write_o  <= 1'b0;
            mem_to_reg_o <= 1'b0;
            mem_write_o  <= 1'b0;
            mem_read_o   <= 1'b0;
            branch_o     <= 1'b0;
            jump_o       <= 1'b0;
        end else if (!load_enable_i) begin
            if (flush_i) begin
                pc_plus4_o   <= 32'b0;
                alu_result_o <= 32'b0;
                rs2_data_o   <= 32'b0;
                rd_addr_o    <= 5'b0;
                zero_o       <= 1'b0;
                reg_write_o  <= 1'b0;
                mem_to_reg_o <= 1'b0;
                mem_write_o  <= 1'b0;
                mem_read_o   <= 1'b0;
                branch_o     <= 1'b0;
                jump_o       <= 1'b0;
            end else begin
                pc_plus4_o   <= pc_plus4_i;
                alu_result_o <= alu_result_i;
                rs2_data_o   <= rs2_data_i;
                rd_addr_o    <= rd_addr_i;
                zero_o       <= zero_i;
                reg_write_o  <= reg_write_i;
                mem_to_reg_o <= mem_to_reg_i;
                mem_write_o  <= mem_write_i;
                mem_read_o   <= mem_read_i;
                branch_o     <= branch_i;
                jump_o       <= jump_i;
            end
        end
    end

endmodule

module mem_wb_reg (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        load_enable_i,
    input  wire [31:0] pc_plus4_i,
    input  wire [31:0] alu_result_i,
    input  wire [31:0] mem_data_i,
    input  wire [4:0]  rd_addr_i,
    input  wire        reg_write_i,
    input  wire        mem_to_reg_i,
    input  wire        jump_i,
    output reg  [31:0] pc_plus4_o,
    output reg  [31:0] alu_result_o,
    output reg  [31:0] mem_data_o,
    output reg  [4:0]  rd_addr_o,
    output reg         reg_write_o,
    output reg         mem_to_reg_o,
    output reg         jump_o
);

    // Ultimo registrador de pipeline antes do write-back.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pc_plus4_o   <= 32'b0;
            alu_result_o <= 32'b0;
            mem_data_o   <= 32'b0;
            rd_addr_o    <= 5'b0;
            reg_write_o  <= 1'b0;
            mem_to_reg_o <= 1'b0;
            jump_o       <= 1'b0;
        end else if (!load_enable_i) begin
            pc_plus4_o   <= pc_plus4_i;
            alu_result_o <= alu_result_i;
            mem_data_o   <= mem_data_i;
            rd_addr_o    <= rd_addr_i;
            reg_write_o  <= reg_write_i;
            mem_to_reg_o <= mem_to_reg_i;
            jump_o       <= jump_i;
        end
    end

endmodule
// =============================================================================
// Contador de programa com suporte a reset, stall e redirecionamento.
// A CPU fica congelada quando load_enable_i esta ativo durante carga externa.
// =============================================================================

module program_counter (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        stall_i,
    input  wire        load_enable_i,
    input  wire        branch_taken_i,
    input  wire        jump_i,
    input  wire [31:0] target_addr_i,
    output wire [31:0] pc_o,
    output wire [31:0] pc_plus4_o
);

    reg  [31:0] pc_reg;
    wire [31:0] pc_plus4 = pc_reg + 32'd4;
    wire [31:0] pc_next  = (branch_taken_i || jump_i) ? target_addr_i : pc_plus4;

    // Registrador do PC propriamente dito.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pc_reg <= 32'b0;
        end else if (!load_enable_i) begin
            if (!stall_i) begin
                pc_reg <= pc_next;
            end
        end
    end

    assign pc_o       = pc_reg;
    assign pc_plus4_o = pc_plus4;

endmodule
// =============================================================================
// Banco de registradores escalar RV32I.
// Implementa 32 registradores de 32 bits com x0 fixo em zero e porta de debug.
// =============================================================================

module register_file (
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        we_i,
    input  wire [4:0]  rs1_addr_i,
    input  wire [4:0]  rs2_addr_i,
    input  wire [4:0]  rd_addr_i,
    input  wire [31:0] rd_data_i,
    output wire [31:0] rs1_data_o,
    output wire [31:0] rs2_data_o,
    output wire [31:0] reg_debug_o,
    input  wire [4:0]  reg_sel_i
);

    integer idx;
    reg [31:0] registers [0:31];

    // Escrita sincrona e reset completo para facilitar depuracao no Digital.
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            for (idx = 0; idx < 32; idx = idx + 1) begin
                registers[idx] <= 32'b0;
            end
        end else if (we_i && (rd_addr_i != 5'b00000)) begin
            registers[rd_addr_i] <= rd_data_i;
        end
    end

    // Leituras assincronas com tratamento explicito de x0.
    assign rs1_data_o  = (rs1_addr_i == 5'b00000) ? 32'b0 : registers[rs1_addr_i];
    assign rs2_data_o  = (rs2_addr_i == 5'b00000) ? 32'b0 : registers[rs2_addr_i];
    assign reg_debug_o = (reg_sel_i  == 5'b00000) ? 32'b0 : registers[reg_sel_i];

endmodule
