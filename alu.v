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
