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
