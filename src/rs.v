`include "def.v"

module ReservationStation(
           input wire clk_in,
           input wire rst_in,
           input wire rdy_in,
           input wire flush_enable,
           output wire rs_full,

           input wire decoder2rs_enable,
           input wire[`RS_LINE_LENGTH-1:0] decoder2rs_entry,

           output reg                  rs2alu_enable,
           output reg[`DATA_WIDTH]     rs2alu_rs1,
           output reg[`DATA_WIDTH]     rs2alu_rs2,
           output reg[`DATA_WIDTH]     rs2alu_imm,
           output reg[`INS_TYPE_WIDTH] rs2alu_ins_type,
           output reg[`ADDR_WIDTH]     rs2alu_pc,
           output reg[`ROB_WIDTH]      rs2alu_reorder,

           input wire alu2rs_bypass_enable,
           input wire[`ROB_WIDTH] alu2rs_bypass_reorder,
           input wire[`DATA_WIDTH] alu2rs_bypass_value,

           input wire lsu2rs_bypass_enable,
           input wire[`ROB_WIDTH] lsu2rs_bypass_reorder,
           input wire[`DATA_WIDTH] lsu2rs_bypass_value
       );

reg[`RS_LINE_LENGTH-1:0] rs_array[`RS_SIZE-1:0];
wire [`RS_SIZE-1:0] ready_table;

assign ready_table[0] =rs_array[0] [`RS_READY_1]&&rs_array[0] [`RS_READY_2]&&rs_array[0] [`RS_BUSY];
assign ready_table[1] =rs_array[1] [`RS_READY_1]&&rs_array[1] [`RS_READY_2]&&rs_array[1] [`RS_BUSY];
assign ready_table[2] =rs_array[2] [`RS_READY_1]&&rs_array[2] [`RS_READY_2]&&rs_array[2] [`RS_BUSY];
assign ready_table[3] =rs_array[3] [`RS_READY_1]&&rs_array[3] [`RS_READY_2]&&rs_array[3] [`RS_BUSY];
assign ready_table[4] =rs_array[4] [`RS_READY_1]&&rs_array[4] [`RS_READY_2]&&rs_array[4] [`RS_BUSY];
assign ready_table[5] =rs_array[5] [`RS_READY_1]&&rs_array[5] [`RS_READY_2]&&rs_array[5] [`RS_BUSY];
assign ready_table[6] =rs_array[6] [`RS_READY_1]&&rs_array[6] [`RS_READY_2]&&rs_array[6] [`RS_BUSY];
assign ready_table[7] =rs_array[7] [`RS_READY_1]&&rs_array[7] [`RS_READY_2]&&rs_array[7] [`RS_BUSY];
assign ready_table[8] =rs_array[8] [`RS_READY_1]&&rs_array[8] [`RS_READY_2]&&rs_array[8] [`RS_BUSY];
assign ready_table[9] =rs_array[9] [`RS_READY_1]&&rs_array[9] [`RS_READY_2]&&rs_array[9] [`RS_BUSY];
assign ready_table[10]=rs_array[10][`RS_READY_1]&&rs_array[10][`RS_READY_2]&&rs_array[10][`RS_BUSY];
assign ready_table[11]=rs_array[11][`RS_READY_1]&&rs_array[11][`RS_READY_2]&&rs_array[11][`RS_BUSY];
assign ready_table[12]=rs_array[12][`RS_READY_1]&&rs_array[12][`RS_READY_2]&&rs_array[12][`RS_BUSY];
assign ready_table[13]=rs_array[13][`RS_READY_1]&&rs_array[13][`RS_READY_2]&&rs_array[13][`RS_BUSY];
assign ready_table[14]=rs_array[14][`RS_READY_1]&&rs_array[14][`RS_READY_2]&&rs_array[14][`RS_BUSY];
assign ready_table[15]=rs_array[15][`RS_READY_1]&&rs_array[15][`RS_READY_2]&&rs_array[15][`RS_BUSY];

wire[`RS_WIDTH] free_index;
wire [`RS_WIDTH]ready_index;
wire[`RS_LINE_LENGTH-1:0] ready_entry=rs_array[ready_index];

wire [`RS_LINE_LENGTH-1:0]dbg_line=rs_array[1];

assign rs_full=free_index==`ZERO_RS;

integer i=0,alu_i=0,lsu_i=0;

initial begin
    rs2alu_enable<=`FALSE;
    rs2alu_rs1<=`ZERO_DATA;
    rs2alu_rs2<=`ZERO_DATA;
    rs2alu_imm<=`ZERO_DATA;
    rs2alu_ins_type<=`ZERO_INS_TYPE;
    rs2alu_pc<=`ZERO_ADDR;
    rs2alu_reorder<=`ZERO_ROB;
    for(i=0;i<`RS_SIZE;i=i+1) begin
        rs_array[i]=`ZERO_RS_LINE;
    end
end


always @(posedge clk_in) begin
    if(rst_in||flush_enable) begin
        for(i=1;i<`RS_SIZE;i=i+1) begin
            rs_array[i][`RS_BUSY]<=`FALSE;
            rs2alu_enable<=`FALSE;
        end
    end
    else if(rdy_in) begin
        if(decoder2rs_enable&&!rs_full) begin
            rs_array[free_index]<=decoder2rs_entry;
        end
        if(ready_table!=`ZERO_RS) begin
            rs2alu_enable<=`TRUE;
            rs2alu_imm<=ready_entry[`RS_A];
            rs2alu_ins_type<=ready_entry[`RS_TYPE];
            rs2alu_pc<=ready_entry[`RS_PC];
            rs2alu_reorder<=ready_entry[`RS_REORDER];
            rs2alu_rs1<=ready_entry[`RS_VJ];
            rs2alu_rs2<=ready_entry[`RS_VK];
            rs_array[ready_index][`RS_BUSY]<=`FALSE;
        end
        else begin
            rs2alu_enable<=`FALSE;
        end
        if(alu2rs_bypass_enable) begin
            for(alu_i=1;alu_i<`RS_SIZE;alu_i=alu_i+1) begin
                if(decoder2rs_enable&&!rs_full&&alu_i==free_index) begin
                    if(rs_array[alu_i][`RS_QJ]==alu2rs_bypass_reorder&&!rs_array[alu_i][`RS_READY_1]) begin
                        rs_array[alu_i][`RS_VJ]<=alu2rs_bypass_value;
                        rs_array[alu_i][`RS_READY_1]<=`TRUE;
                    end
                    if(rs_array[alu_i][`RS_QK]==alu2rs_bypass_reorder&&!rs_array[alu_i][`RS_READY_2]) begin
                        rs_array[alu_i][`RS_VK]<=alu2rs_bypass_value;
                        rs_array[alu_i][`RS_READY_2]<=`TRUE;
                    end
                end
                else begin
                if(rs_array[alu_i][`RS_BUSY]) begin
                    if(rs_array[alu_i][`RS_QJ]==alu2rs_bypass_reorder&&!rs_array[alu_i][`RS_READY_1]) begin
                        rs_array[alu_i][`RS_VJ]<=alu2rs_bypass_value;
                        rs_array[alu_i][`RS_READY_1]<=`TRUE;
                    end
                    if(rs_array[alu_i][`RS_QK]==alu2rs_bypass_reorder&&!rs_array[alu_i][`RS_READY_2]) begin
                        rs_array[alu_i][`RS_VK]<=alu2rs_bypass_value;
                        rs_array[alu_i][`RS_READY_2]<=`TRUE;
                    end
                    end
                end
            end
        end
        if(lsu2rs_bypass_enable) begin
            for(lsu_i=1;lsu_i<`RS_SIZE;lsu_i=lsu_i+1) begin
                if(decoder2rs_enable&&!rs_full&&lsu_i==free_index) begin
                    if(rs_array[lsu_i][`RS_QJ]==lsu2rs_bypass_reorder&&!rs_array[lsu_i][`RS_READY_1]) begin
                        rs_array[lsu_i][`RS_VJ]<=lsu2rs_bypass_value;
                        rs_array[lsu_i][`RS_READY_1]<=`TRUE;
                    end
                    if(rs_array[lsu_i][`RS_QK]==lsu2rs_bypass_reorder&&!rs_array[lsu_i][`RS_READY_2]) begin
                        rs_array[lsu_i][`RS_VK]<=lsu2rs_bypass_value;
                        rs_array[lsu_i][`RS_READY_2]<=`TRUE;
                    end
                end
                else begin
                    if(rs_array[lsu_i][`RS_BUSY]) begin
                        if(rs_array[lsu_i][`RS_QJ]==lsu2rs_bypass_reorder&&!rs_array[lsu_i][`RS_READY_1]) begin
                            rs_array[lsu_i][`RS_VJ]<=lsu2rs_bypass_value;
                            rs_array[lsu_i][`RS_READY_1]<=`TRUE;
                        end
                        if(rs_array[lsu_i][`RS_QK]==lsu2rs_bypass_reorder&&!rs_array[lsu_i][`RS_READY_2]) begin
                            rs_array[lsu_i][`RS_VK]<=lsu2rs_bypass_value;
                            rs_array[lsu_i][`RS_READY_2]<=`TRUE;
                        end
                    end
                end
            end
        end
    end
end


assign free_index =  !rs_array[1][`RS_BUSY]  ? 4'd1  :
       !rs_array[2][`RS_BUSY]   ? 4'd2  :
       !rs_array[3][`RS_BUSY]   ? 4'd3  :
       !rs_array[4][`RS_BUSY]   ? 4'd4  :
       !rs_array[5][`RS_BUSY]   ? 4'd5  :
       !rs_array[6][`RS_BUSY]   ? 4'd6  :
       !rs_array[7][`RS_BUSY]   ? 4'd7  :
       !rs_array[8][`RS_BUSY]   ? 4'd8  :
       !rs_array[9][`RS_BUSY]   ? 4'd9  :
       !rs_array[10][`RS_BUSY]  ? 4'd10 :
       !rs_array[11][`RS_BUSY]  ? 4'd11 :
       !rs_array[12][`RS_BUSY]  ? 4'd12 :
       !rs_array[13][`RS_BUSY]  ? 4'd13 :
       !rs_array[14][`RS_BUSY]  ? 4'd14 :
       !rs_array[15][`RS_BUSY]  ? 4'd15 :
       `ZERO_RS;

assign ready_index =    ready_table[1]  ? 4'd1  :
       ready_table[2]  ? 4'd2  :
       ready_table[3]  ? 4'd3  :
       ready_table[4]  ? 4'd4  :
       ready_table[5]  ? 4'd5  :
       ready_table[6]  ? 4'd6  :
       ready_table[7]  ? 4'd7  :
       ready_table[8]  ? 4'd8  :
       ready_table[9]  ? 4'd9  :
       ready_table[10] ? 4'd10 :
       ready_table[11] ? 4'd11 :
       ready_table[12] ? 4'd12 :
       ready_table[13] ? 4'd13 :
       ready_table[14] ? 4'd14 :
       ready_table[15] ? 4'd15 :
       `ZERO_RS;

endmodule
