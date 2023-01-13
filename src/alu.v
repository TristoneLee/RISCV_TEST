`include "def.v"

module ALU(
           input wire  rs2alu_enable,
           input wire [`DATA_WIDTH] rs2alu_rs1,
           input wire [`DATA_WIDTH] rs2alu_rs2,
           input wire [`DATA_WIDTH] rs2alu_imm,
           input wire [`INS_TYPE_WIDTH] rs2alu_ins_type,
           input wire [`ADDR_WIDTH] rs2alu_pc,
           input wire [`ROB_WIDTH] rs2alu_reorder,

           output wire alu2rs_bypass_enable,
           output wire[`ROB_WIDTH] alu2rs_bypass_reorder,
           output wire[`DATA_WIDTH] alu2rs_bypass_value,

           output wire alu2rob_enable,
           output wire[`ROB_WIDTH] alu2rob_reorder,
           output wire[`DATA_WIDTH] alu2rob_value,
           output wire[`ADDR_WIDTH] alu2rob_pc,

           output wire alu2lsu_bypass_enable,
           output wire [`ROB_WIDTH] alu2lsu_bypass_reorder,
           output wire [`DATA_WIDTH] alu2lsu_bypass_value
       );

reg[`DATA_WIDTH] result;
reg[`ADDR_WIDTH] pc;

assign alu2rs_bypass_enable=rs2alu_enable;
assign alu2rob_enable=rs2alu_enable;
assign alu2rs_bypass_reorder=rs2alu_reorder;
assign alu2rob_reorder=rs2alu_reorder;
assign alu2rob_value=result;
assign alu2rs_bypass_value=result;
assign alu2rob_pc=pc;
assign alu2lsu_bypass_enable=rs2alu_enable;
assign alu2lsu_bypass_reorder=rs2alu_reorder;
assign alu2lsu_bypass_value=result;

always @(*) begin
    if(rs2alu_enable) begin
        case (rs2alu_ins_type)
            `LUI: begin
                result<=rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `AUIPC: begin
                result <= rs2alu_imm+rs2alu_pc;
                pc<=`ZERO_ADDR;
            end
            `JAL: begin
                result<=rs2alu_pc+4;
                pc<=rs2alu_imm+rs2alu_pc;
            end
            `JALR: begin
                result <= rs2alu_pc+4;
                pc<=(rs2alu_imm+rs2alu_rs1)&(~1);
            end
            `BEQ: begin
                result<=rs2alu_rs1==rs2alu_rs2;
                pc<=rs2alu_pc+rs2alu_imm;
            end
            `BNE: begin
                result<=rs2alu_rs1!=rs2alu_rs2;
                pc<=rs2alu_pc+rs2alu_imm;
            end
            `BLT: begin
                result<= $signed(rs2alu_rs1)<$signed(rs2alu_rs2);
                pc<=rs2alu_pc+rs2alu_imm;
            end
            `BGE: begin
                result<=$signed(rs2alu_rs1)>=$signed(rs2alu_rs2);
                pc<=rs2alu_pc+rs2alu_imm;
            end
            `BLTU: begin
                result<=rs2alu_rs1<rs2alu_rs2;
                pc<=rs2alu_pc+rs2alu_imm;
            end
            `BGEU: begin
                result<=rs2alu_rs1>=rs2alu_rs2;
                pc<=rs2alu_pc+rs2alu_imm;
            end

            `ADDI: begin
                result<=rs2alu_rs1+rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `SLTI: begin
                result<=$signed(rs2alu_rs1)<$signed(rs2alu_imm);
                pc<=`ZERO_ADDR;
            end
            `SLTIU: begin
                result<=rs2alu_rs1<rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `XORI: begin
                result<=rs2alu_rs1^rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `ORI: begin
                result<=rs2alu_rs1|rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `ANDI: begin
                result<=rs2alu_rs1&rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `SLLI: begin
                result<=rs2alu_rs1<<rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `SRLI: begin
                result<=rs2alu_rs1>>rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `SRAI: begin
                result<=rs2alu_rs1>>>rs2alu_imm;
                pc<=`ZERO_ADDR;
            end
            `ADD: begin
                result<=rs2alu_rs1+rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `SUB: begin
                result<=rs2alu_rs1-rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `SLL: begin
                result<=rs2alu_rs1<<rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `SLT: begin
                result<=$signed(rs2alu_rs1)<$signed(rs2alu_rs2);
                pc<=`ZERO_ADDR;
            end
            `SLTU: begin
                result<=rs2alu_rs1<rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `XOR: begin
                result<=rs2alu_rs1^rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `SRL: begin
                result<=rs2alu_rs1>>rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `SRA: begin
                result<=rs2alu_rs1>>>rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `OR: begin
                result<=rs2alu_rs1|rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
            `AND: begin
                result<=rs2alu_rs1&rs2alu_rs2;
                pc<=`ZERO_ADDR;
            end
        endcase
    end
    else begin
        result<=`ZERO_DATA;
        pc<=`ZERO_ADDR;
    end
end
endmodule
