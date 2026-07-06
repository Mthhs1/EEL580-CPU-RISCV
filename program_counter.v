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
