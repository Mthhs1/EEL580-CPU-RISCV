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
