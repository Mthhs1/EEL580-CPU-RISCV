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
