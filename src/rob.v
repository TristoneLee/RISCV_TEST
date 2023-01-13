`include "def.v"

module ReorderBuffer(
           input wire clk_in,
           input wire rst_in,
           input wire rdy_in,

           output reg flush_enable,

           output wire rob_full,

           output reg[`ADDR_WIDTH] rob2pc_pc,
           output reg rob2pc_enable,

           input  wire [`REG_WIDTH] decoder2rob_rs1_request,
           input  wire [`REG_WIDTH] decoder2rob_rs2_request,

           output wire[`ROB_WIDTH] rob2decoder_rs1_rename,
           output wire[`ROB_WIDTH] rob2decoder_rs2_rename,
           output wire [`DATA_WIDTH]rob2decoder_rs1_value,
           output wire [`DATA_WIDTH]rob2decoder_rs2_value,
           output wire [`ROB_WIDTH] rob2decoder_reorder,
           output wire rob2decoder_rs1_if_rename,
           output wire rob2decoder_rs2_if_rename,

           input wire[`ROB_LINE_LENGTH-1:0] decoder2rob_robline,
           input wire decoder2rob_reserve_enable,
           input wire decoder2rob_enable,

           output wire [`REG_WIDTH] rob2reg_rs1_request,
           output wire [`REG_WIDTH] rob2reg_rs2_request,
           input  wire[`DATA_WIDTH] reg2rob_rs1_value,
           input  wire[`DATA_WIDTH] reg2rob_rs2_value,
           input  wire[`DATA_WIDTH] reg2rob_rs1_rename,
           input  wire[`DATA_WIDTH] reg2rob_rs2_rename,
           input  wire reg2rob_rs1_if_rename,
           input  wire reg2rob_rs2_if_rename,
           output wire [`ROB_WIDTH] rob2reg_reorder,

           output wire rob2reg_reserve_enable,
           output wire[`REG_WIDTH] rob2reg_reserve_rd,
           output wire[`ROB_WIDTH] rob2reg_reserve_reorder,

           output reg rob2reg_commit_enable,
           output reg[`REG_WIDTH] rob2reg_commit_des,
           output reg[`DATA_WIDTH] rob2reg_commit_value,
           output reg[`ROB_WIDTH] rob2reg_commit_reorder,
           output reg[`ADDR_WIDTH]rob2reg_commit_pc,

           input wire alu2rob_enable,
           input wire[`ROB_WIDTH] alu2rob_reorder,
           input wire[`DATA_WIDTH] alu2rob_value,
           input wire[`ADDR_WIDTH] alu2rob_pc,

           input wire  lsu2rob_enable,
           input wire [`ROB_WIDTH]  lsu2rob_reorder,
           input wire [`DATA_WIDTH] lsu2rob_value,

           output reg [`ROB_WIDTH] rob2lsu_store_reorder,
           output reg rob2lsu_store_enable
       );

reg [`ROB_WIDTH]head;
reg [`ROB_WIDTH]tail;
wire [`ROB_WIDTH]next_head=head+1;
reg [`ROB_LINE_LENGTH-1:0] rob_queue[`ROB_SIZE-1:0];

reg empty;
wire full=head==tail&&!empty;

wire head_ready=rob_queue[head][`ROB_READY]&&rob_queue[head][`ROB_BUSY];
wire head_pc=rob_queue[head][`ROB_PC];

assign rob2reg_rs1_request=decoder2rob_rs1_request;
assign rob2reg_rs2_request=decoder2rob_rs2_request;

assign rob2decoder_rs1_rename=reg2rob_rs1_if_rename?reg2rob_rs1_rename:`ZERO_ROB;
assign rob2decoder_rs1_if_rename=reg2rob_rs1_if_rename&&!rob_queue[rob2decoder_rs1_rename][`ROB_READY];
assign rob2decoder_rs1_value=reg2rob_rs1_if_rename?(rob2decoder_rs1_if_rename?`ZERO_DATA:rob_queue[reg2rob_rs1_rename][`ROB_VALUE]):reg2rob_rs1_value;
assign rob2decoder_rs2_rename=reg2rob_rs2_if_rename?reg2rob_rs2_rename:`ZERO_ROB;
assign rob2decoder_rs2_if_rename=reg2rob_rs2_if_rename&&!rob_queue[rob2decoder_rs2_rename][`ROB_READY];
assign rob2decoder_rs2_value=reg2rob_rs2_if_rename?(rob2decoder_rs2_if_rename?`ZERO_DATA:rob_queue[reg2rob_rs2_rename][`ROB_VALUE]):reg2rob_rs2_value;
assign rob2decoder_reorder=tail;
assign rob2reg_reorder=tail;
assign rob_full=full;

assign rob2reg_reserve_rd=decoder2rob_robline[`ROB_DEST];
assign rob2reg_reserve_reorder= tail;
assign rob2reg_reserve_enable=decoder2rob_reserve_enable;

integer i;

initial begin
    for(i=0;i<`ROB_SIZE;i=i+1) begin
        rob_queue[i]<=`ZERO_ROB_LINE;
    end
    head<=`ZERO_ROB;
    tail<=`ZERO_ROB;
    flush_enable<=`FALSE;
    empty<=`TRUE;
    rob2lsu_store_enable<=`FALSE;
    rob2lsu_store_reorder<=`ZERO_ROB;
    rob2reg_commit_des<=`ZERO_REG;
    rob2reg_commit_enable<=`FALSE;
    rob2reg_commit_reorder<=`ZERO_ROB;
    rob2reg_commit_value<=`ZERO_DATA;
    rob2pc_pc<=`ZERO_ADDR;
end

always @(posedge clk_in) begin
    // $display ("%x",rob_queue[0]);
    if(rst_in||flush_enable) begin
        for(i=0;i<`ROB_SIZE;i=i+1) begin
            rob_queue[i]=`ZERO_ROB_LINE;
        end
        head<=`ZERO_ROB;
        tail<=`ZERO_ROB;
        flush_enable<=`FALSE;
        empty<=`TRUE;
        rob2lsu_store_enable<=`FALSE;
        rob2lsu_store_reorder<=`ZERO_ROB;
        rob2reg_commit_des<=`ZERO_REG;
        rob2reg_commit_enable<=`FALSE;
        rob2reg_commit_reorder<=`ZERO_ROB;
        rob2reg_commit_value<=`ZERO_DATA;
        rob2pc_pc<=`ZERO_ADDR;
        rob2pc_enable<=`FALSE;
    end
    else if(rdy_in) begin
        //commit procedure
        if(head_ready) begin
            if(rob_queue[head][`ROB_TYPE]==`JALR||rob_queue[head][`ROB_TYPE]==`JAL) begin
                flush_enable<=`TRUE;
                rob2pc_enable<=`TRUE;
                rob2pc_pc<=rob_queue[head][`ROB_JUMP];
                // if(rob_queue[head][`ROB_DEST]==0)begin
                //   $display("%x\n",rob_queue[head][`ROB_PC]);
                // end
                rob2reg_commit_des<=rob_queue[head][`ROB_DEST];
                rob2reg_commit_enable<=`TRUE;
                rob2reg_commit_reorder<=head;
                rob2reg_commit_value<=rob_queue[head][`ROB_VALUE];
                rob2reg_commit_pc<=rob_queue[head][`ROB_PC];
                // if(rob_queue[head][`ROB_TYPE]==`JALR)begin
                //     $display("%x",rob_queue[head][`ROB_PC]);
                //     $display("\t%x",rob_queue[head][`ROB_JUMP]);
                // end
            end
            else if (is_branch( rob_queue[head][`ROB_TYPE])) begin
                if(rob_queue[head][`ROB_VALUE_ZERO]==`TRUE) begin
                    flush_enable<=`TRUE;
                    rob2pc_pc<=rob_queue[head][`ROB_JUMP];
                    rob2pc_enable<=`TRUE;
                    // $display("%x",rob_queue[head][`ROB_PC]);
                    // $display("\t%x",rob_queue[head][`ROB_JUMP]);
                end
            end
            else if(is_store( rob_queue[head][`ROB_TYPE])) begin
                rob2lsu_store_enable<=`TRUE;
                rob2lsu_store_reorder<=head;
                rob2pc_enable<=`FALSE;
            end
            else begin
                rob2reg_commit_des<=rob_queue[head][`ROB_DEST];
                rob2reg_commit_enable<=`TRUE;
                rob2reg_commit_reorder<=head;
                rob2reg_commit_value<=rob_queue[head][`ROB_VALUE];
                rob2reg_commit_pc<=rob_queue[head][`ROB_PC];
                rob2pc_enable<=`FALSE;
                rob2lsu_store_enable<=`FALSE;
            end
            head<=next_head;
            rob_queue[head][`ROB_BUSY]<=`FALSE;
            if(next_head==tail) begin
                empty<=`TRUE;
            end
        end
        else begin
            rob2pc_enable<=`FALSE;
            rob2reg_commit_enable<=`FALSE;
        end
        //update procedure
        if(alu2rob_enable) begin
            rob_queue[alu2rob_reorder][`ROB_VALUE] <=alu2rob_value;
            rob_queue[alu2rob_reorder][`ROB_JUMP]  <=alu2rob_pc;
            rob_queue[alu2rob_reorder][`ROB_READY] <=`TRUE;
        end
        if(lsu2rob_enable) begin
            rob_queue[lsu2rob_reorder][`ROB_READY]<=`TRUE;
            rob_queue[lsu2rob_reorder][`ROB_VALUE]<=lsu2rob_value;
        end
        //receive from decoder
        if(!full&&decoder2rob_enable) begin
            tail<=tail+1;
            rob_queue[tail]<=decoder2rob_robline;
            empty<=`FALSE;
        end
    end
end

function reg is_branch(input [`INS_TYPE_WIDTH] type) ;
    begin
        is_branch = (type == `BEQ || type == `BNE || type == `BLT || type == `BGE || type == `BLTU|| type == `BGEU);
    end
endfunction

function reg is_store(input [`INS_TYPE_WIDTH] type) ;
    begin
        is_store =  (type == `SB || type == `SH || type == `SW);
    end
endfunction

endmodule
