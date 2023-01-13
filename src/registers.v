`include "def.v"

module Registers(
           input wire clk_in,
           input wire rdy_in,
           input wire rst_in,
           input wire flush_enable,

           input wire[`REG_WIDTH] rob2reg_rs1_request,
           input wire[`REG_WIDTH] rob2reg_rs2_request,
           output wire[`DATA_WIDTH] reg2rob_rs1_value,
           output wire[`DATA_WIDTH] reg2rob_rs2_value,
           output wire[`DATA_WIDTH] reg2rob_rs1_rename,
           output wire[`DATA_WIDTH] reg2rob_rs2_rename,
           output wire reg2rob_rs1_if_rename,
           output wire reg2rob_rs2_if_rename,
           input wire [`ROB_WIDTH] rob2reg_reorder,

           input wire rob2reg_reserve_enable,
           input wire[`REG_WIDTH] rob2reg_reserve_rd,
           input wire[`ROB_WIDTH] rob2reg_reserve_reorder,

           input wire rob2reg_commit_enable,
           input wire[`REG_WIDTH] rob2reg_commit_des,
           input wire[`DATA_WIDTH] rob2reg_commit_value,
           input wire[`ROB_WIDTH] rob2reg_commit_reorder,
           input wire[`ADDR_WIDTH] rob2reg_commit_pc
       );

reg[`DATA_WIDTH] regs[`REG_SIZE-1:0];
reg[`ROB_WIDTH] reg_rename_table[`REG_SIZE-1:0];
reg reg_if_rename[`REG_SIZE-1:0];

assign reg2rob_rs1_if_rename=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs1_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?`TRUE:reg_if_rename[rob2reg_rs1_request];
assign reg2rob_rs1_value=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs1_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?`ZERO_DATA:(reg_if_rename[rob2reg_rs1_request]?`ZERO_DATA:regs[rob2reg_rs1_request]);
assign reg2rob_rs1_rename=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs1_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?rob2reg_reserve_reorder:(reg_if_rename[rob2reg_rs1_request]?reg_rename_table[rob2reg_rs1_request]:`ZERO_ROB);
assign reg2rob_rs2_if_rename=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs2_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?`TRUE:reg_if_rename[rob2reg_rs2_request];
assign reg2rob_rs2_value=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs2_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?`ZERO_DATA:(reg_if_rename[rob2reg_rs2_request]?`ZERO_DATA:regs[rob2reg_rs2_request]);
assign reg2rob_rs2_rename=(rob2reg_reserve_enable&&rob2reg_reserve_rd==rob2reg_rs2_request&&rob2reg_reserve_reorder!=rob2reg_reorder)?rob2reg_reserve_reorder:(reg_if_rename[rob2reg_rs2_request]?reg_rename_table[rob2reg_rs2_request]:`ZERO_ROB);

wire [`DATA_WIDTH] reg_a0 = regs[5'd10];
wire [`DATA_WIDTH] reg_a2 = regs[5'd12];
wire [`DATA_WIDTH] reg_a1 = regs[5'd11];
wire [`DATA_WIDTH] reg_a3 = regs[5'd13];
wire [`DATA_WIDTH] reg_a4 = regs[5'd14];
wire [`DATA_WIDTH] reg_a5 = regs[5'd15];
wire [`DATA_WIDTH] reg_a6 = regs[5'd16];
wire [`DATA_WIDTH] reg_s0 = regs[5'd8];
wire [`DATA_WIDTH] reg_s2 = regs[5'd18];
wire [`DATA_WIDTH] reg_zero = regs[5'd0];
wire [`DATA_WIDTH] reg_s4 = regs[5'd20];
wire [`DATA_WIDTH] reg_s6 = regs[5'd22];
wire [`DATA_WIDTH] reg_s7 = regs[5'd23];
wire [`DATA_WIDTH] reg_s1 = regs[5'd9];
wire [`DATA_WIDTH] reg_s11 = regs[5'd27];
wire [`DATA_WIDTH] reg_ra = regs[5'd1];
integer file;

integer i;

initial begin
    file=  $fopen("dataa.txt");
    for(i=0;i<`REG_SIZE;i=i+1) begin
        regs[i]<=`ZERO_DATA;
        reg_if_rename[i]<=`FALSE;
        reg_rename_table[i]<=4'b0000;
    end
end

always @(posedge clk_in ) begin
    if(rst_in) begin
        for(i=0;i<`REG_SIZE;i=i+1) begin
            regs[i]<=`ZERO_DATA;
            reg_if_rename[i]<=`FALSE;
            reg_rename_table[i]<=`ZERO_ROB;
        end
    end
    else if(rdy_in) begin
        if (flush_enable) begin
            for(i=0;i<`REG_SIZE;i=i+1) begin
                reg_if_rename[i]<=`FALSE;
                reg_rename_table[i]<=`ZERO_ROB;
            end
            if(rob2reg_commit_enable&&rob2reg_commit_des!=5'd0) begin
                // $fdisplay(file,"%d\t%x\t%x",rob2reg_commit_des,rob2reg_commit_value,rob2reg_commit_pc);
                regs[rob2reg_commit_des]<=rob2reg_commit_value;
            end
        end
        else begin
            if(rob2reg_commit_enable&&rob2reg_commit_des!=5'd0) begin
                // $fdisplay(file,"%d\t%x\t%x",rob2reg_commit_des,rob2reg_commit_value,rob2reg_commit_pc);
                regs[rob2reg_commit_des]<=rob2reg_commit_value;
                if(reg_rename_table[rob2reg_commit_des]==rob2reg_commit_reorder) begin
                    reg_rename_table[rob2reg_commit_des]<=`ZERO_ROB;
                    reg_if_rename[rob2reg_commit_des]<=`FALSE;
                end
            end
            if(rob2reg_reserve_enable) begin
                reg_rename_table[rob2reg_reserve_rd]<=rob2reg_reserve_reorder;
                reg_if_rename[rob2reg_reserve_rd]<=`TRUE;
            end
        end
    end
end



endmodule
