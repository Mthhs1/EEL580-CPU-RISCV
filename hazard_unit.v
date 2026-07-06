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
