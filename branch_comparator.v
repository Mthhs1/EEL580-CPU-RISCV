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
