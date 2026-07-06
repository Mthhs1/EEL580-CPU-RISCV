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
