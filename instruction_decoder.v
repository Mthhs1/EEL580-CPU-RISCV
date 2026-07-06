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
