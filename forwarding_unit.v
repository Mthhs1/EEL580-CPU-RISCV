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
