`include "def.v"

module LoadStoreUnit(
           input wire clk_in,
           input wire rst_in,
           input wire rdy_in,
           input wire flush_enable,
           output wire lsu_full,

           input wire[`DATA_WIDTH] memCon2lsu_return,
           input wire memCon2lsu_enable,
           output reg[1:0] lsu2memCon_width,
           output reg[`ADDR_WIDTH] lsu2memCon_addr,
           output reg lsu2memCon_rw,
           output reg lsu2memCon_enable,
           output reg[`DATA_WIDTH] lsu2memCon_value,
           output reg lsu2memCon_ifSigned,

           input wire decoder2lsu_enable,
           input wire[`RS_LINE_LENGTH-1:0] decoder2lsu_entry,

           output reg lsu2rs_bypass_enable,
           output reg[`ROB_WIDTH] lsu2rs_bypass_reorder,
           output reg[`DATA_WIDTH] lsu2rs_bypass_value,

           input wire alu2lsu_bypass_enable,
           input wire [`ROB_WIDTH] alu2lsu_bypass_reorder,
           input wire [`DATA_WIDTH] alu2lsu_bypass_value,

           output reg lsu2rob_enable,
           output reg[`ROB_WIDTH]  lsu2rob_reorder,
           output reg[`DATA_WIDTH] lsu2rob_value,

           input wire [`ROB_WIDTH] rob2lsu_store_reorder,
           input wire  rob2lsu_store_enable
       );

reg[`RS_LINE_LENGTH-1:0] lsu_queue[`LSU_SIZE-1:0];
reg store_enable_table[`LSU_SIZE-1:0];

reg [`LSU_WIDTH]head;
reg [`LSU_WIDTH]tail;
reg empty;
reg busy;
wire [`LSU_WIDTH]next_head=head+1;
wire full = head == tail&&!empty;
wire head_next_ready=(store_enable_table[next_head]||!is_store(lsu_queue[next_head][`RS_TYPE]))&&lsu_queue[next_head][`RS_BUSY]&&lsu_queue[next_head][`RS_READY_1]&&lsu_queue[next_head][`RS_READY_2];
wire head_ready=(store_enable_table[head]||!is_store(lsu_queue[head][`RS_TYPE]))&&lsu_queue[head][`RS_BUSY]&&lsu_queue[head][`RS_READY_1]&&lsu_queue[head][`RS_READY_2];
wire head_ifLoad=lsu_queue[head][`RS_TYPE]==`LB||lsu_queue[head][`RS_TYPE]==`LBU||lsu_queue[head][`RS_TYPE]==`LHU||lsu_queue[head][`RS_TYPE]==`LH||lsu_queue[head][`RS_TYPE]==`LW;
wire [`LSU_WIDTH]last_store_enabled=!store_enable_table[head]?head:
     !store_enable_table[head+1]?head+1:
     !store_enable_table[head+2]?head+2:
     !store_enable_table[head+3]?head+3:
     !store_enable_table[head+4]?head+4:
     !store_enable_table[head+5]?head+5:
     !store_enable_table[head+6]?head+6:
     !store_enable_table[head+7]?head+7:
     !store_enable_table[head+8]?head+8:
     !store_enable_table[head+9]?head+9:
     !store_enable_table[head+10]?head+10:
     !store_enable_table[head+11]?head+11:
     !store_enable_table[head+12]?head+12:
     !store_enable_table[head+13]?head+13:
     !store_enable_table[head+14]?head+14:head+15;

reg[`RS_LINE_LENGTH-1:0] write_back_buffer[15:0];
reg [`LSU_WIDTH]buffer_head;
reg [`LSU_WIDTH]buffer_tail;
reg buffer_empty;
wire buffer_full=buffer_head==buffer_tail&&!buffer_empty;


assign lsu_full=full;
assign lsu2decoder_full=full;

integer i,alu_i,rsu_i,rob_i;

initial begin
    head<=`ZERO_LSU;
    tail<=`ZERO_LSU;
    empty<=`TRUE;
    for(i=0;i<`LSU_SIZE;i=i+1) begin
        lsu_queue[i][`RS_BUSY]<=`FALSE;
        store_enable_table[i]<=`FALSE;
    end
    lsu2memCon_enable<=`FALSE;
    lsu2rs_bypass_enable<=`FALSE;
    lsu2rob_enable<=`FALSE;
    lsu2rob_reorder<=`ZERO_ROB;
    lsu2rob_value<=`ZERO_DATA;
    lsu2memCon_addr<=`ZERO_ADDR;
    lsu2memCon_ifSigned<=`FALSE;
    lsu2memCon_rw<=`MEM_READ;
    lsu2memCon_value<=`ZERO_DATA;
    lsu2memCon_width<=2'd0;
    busy<=`FALSE;
end

always @(posedge clk_in) begin
    if(rst_in) begin
        head<=`ZERO_LSU;
        tail<=`ZERO_LSU;
        empty<=`TRUE;
        lsu2memCon_enable<=`FALSE;
        lsu2rs_bypass_enable<=`FALSE;
        lsu2rob_enable<=`FALSE;
        for(i=0;i<`LSU_SIZE;i=i+1) begin
            lsu_queue[i][`RS_BUSY]<=`FALSE;
            store_enable_table[i]<=`FALSE;
        end
        busy<=`FALSE;
    end
    else if (rdy_in) begin
        if(flush_enable&&last_store_enabled==head) begin
            head<=`ZERO_LSU;
            tail<=`ZERO_LSU;
            empty<=`TRUE;
            lsu2memCon_enable<=`FALSE;
            lsu2rs_bypass_enable<=`FALSE;
            lsu2rob_enable<=`FALSE;
            for(i=0;i<`LSU_SIZE;i=i+1) begin
                lsu_queue[i][`RS_BUSY]<=`FALSE;
                store_enable_table[i]<=`FALSE;
            end
            busy<=`FALSE;
        end
        else begin
            if(flush_enable&&!last_store_enabled==head) begin
                if(!full&&decoder2lsu_enable) begin
                    empty<=`FALSE;
                    tail<=last_store_enabled+1;
                    lsu_queue[last_store_enabled]<=decoder2lsu_entry;
                    store_enable_table[last_store_enabled]<=`FALSE;
                end
                else begin
                    tail<=last_store_enabled;
                end
            end
            else if(!full&&decoder2lsu_enable) begin
                empty<=`FALSE;
                tail<=tail+1;
                lsu_queue[tail]<=decoder2lsu_entry;
                store_enable_table[tail]<=`FALSE;
            end
            if(!memCon2lsu_enable) begin
                lsu2rob_enable<=`FALSE;
                lsu2rs_bypass_enable<=`FALSE;
            end
            if(memCon2lsu_enable) begin
                lsu2rs_bypass_enable<=head_ifLoad;
                lsu2rs_bypass_reorder<=lsu_queue[head][`RS_REORDER];
                lsu2rs_bypass_value<=memCon2lsu_return;
                lsu2rob_enable<=head_ifLoad;
                lsu2rob_reorder<=lsu_queue[head][`RS_REORDER];
                lsu2rob_value<=memCon2lsu_return;
                head<=next_head;
                lsu_queue[head][`RS_BUSY]<=`FALSE;
                store_enable_table[head]<=`FALSE;
                //todo 可以压缩周期，读入一个指令同时完成一个指令
                //rw request to memory
                if(next_head==tail) begin
                    empty<=`TRUE;
                end
                if((next_head!=tail)&&head_next_ready) begin
                    case(lsu_queue[next_head][`RS_TYPE])
                        `LB: begin
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd0;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`TRUE;
                        end
                        `LBU: begin
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd0;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                        end
                        `LH: begin
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd1;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`TRUE;
                        end
                        `LHU: begin
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd1;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                        end
                        `LW: begin
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd2;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                        end
                        `SB: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd0;
                            lsu2memCon_value<={{24{1'b0}},lsu_queue[next_head][`RS_VK_BYTE]};
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                            // end
                            // else begin
                            //     lsu2memCon_enable<=`FALSE;
                            //     busy<=`FALSE;
                            // end
                        end
                        `SH: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd1;
                            lsu2memCon_value<={{16{1'b0}},lsu_queue[next_head][`RS_VK_HALF]};
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                            busy<=`TRUE;
                            // end
                            // else begin
                            //     lsu2memCon_enable<=`FALSE;
                            //     busy<=`FALSE;
                            // end
                        end
                        `SW: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[next_head][`RS_VJ]+lsu_queue[next_head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd2;
                            lsu2memCon_value<=lsu_queue[next_head][`RS_VK];
                            lsu2memCon_ifSigned<=`FALSE;
                            lsu2memCon_enable<=`TRUE;
                            busy<=`TRUE;
                            // end
                            // else begin
                            //     lsu2memCon_enable<=`FALSE;
                            //     busy<=`FALSE;
                            // end
                        end
                    endcase
                end
                else begin
                    busy<=`FALSE;
                    lsu2memCon_enable<=`FALSE;
                end
                if(!is_store(lsu_queue[head][`RS_TYPE])) begin
                    if(decoder2lsu_enable&&!full) begin
                        if( lsu_queue[tail][`RS_QJ]==lsu_queue[head][`RS_REORDER]&&!lsu_queue[tail][`RS_READY_1]) begin
                            lsu_queue[tail][`RS_VJ]<=memCon2lsu_return;
                            lsu_queue[tail][`RS_READY_1]<=`TRUE;
                        end
                        if(lsu_queue[tail][`RS_QK]==lsu_queue[head][`RS_REORDER]&&!lsu_queue[tail][`RS_READY_2]) begin
                            lsu_queue[tail][`RS_VK]<=memCon2lsu_return;
                            lsu_queue[tail][`RS_READY_2]<=`TRUE;
                        end
                    end
                    for(i=head;i!=tail;i=i==15?0:i+1) begin
                        if(lsu_queue[i][`RS_QJ]==lsu_queue[head][`RS_REORDER]&&!lsu_queue[i][`RS_READY_1]) begin
                            lsu_queue[i][`RS_VJ]<=memCon2lsu_return;
                            lsu_queue[i][`RS_READY_1]<=`TRUE;
                        end
                        if(lsu_queue[i][`RS_QK]==lsu_queue[head][`RS_REORDER]&&!lsu_queue[i][`RS_READY_2]) begin
                            lsu_queue[i][`RS_VK]<=memCon2lsu_return;
                            lsu_queue[i][`RS_READY_2]<=`TRUE;
                        end
                    end
                end
            end
            else begin
                if(!busy&&head_ready) begin
                    case(lsu_queue[head][`RS_TYPE])
                        `LB: begin
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd0;
                            busy<=`TRUE;
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_ifSigned<=`TRUE;
                        end
                        `LBU: begin
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd0;
                            busy<=`TRUE;
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                        end
                        `LH: begin
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd1;
                            busy<=`TRUE;
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_ifSigned<=`TRUE;
                        end
                        `LHU: begin
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd1;
                            busy<=`TRUE;
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                        end
                        `LW: begin
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_READ;
                            lsu2memCon_width<=2'd2;
                            busy<=`TRUE;
                            lsu2memCon_ifSigned<=`FALSE;
                            lsu2memCon_enable<=`TRUE;
                        end
                        `SB: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd0;
                            lsu2memCon_value<={{24{1'b0}},lsu_queue[head][`RS_VK_BYTE]};
                            lsu2memCon_ifSigned<=`FALSE;
                            busy<=`TRUE;
                            // end
                            // else begin
                            //     busy<=`FALSE;
                            //     lsu2memCon_enable<=`FALSE;
                            // end
                        end
                        `SH: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd1;
                            lsu2memCon_value<={{16{1'b0}},lsu_queue[head][`RS_VK_HALF]};
                            lsu2memCon_ifSigned<=`FALSE;
                            busy<=`TRUE;
                            // end
                            // else begin
                            //     busy<=`FALSE;
                            //     lsu2memCon_enable<=`FALSE;
                            // end
                        end
                        `SW: begin
                            // if(rob2lsu_store_enable) begin
                            lsu2memCon_enable<=`TRUE;
                            lsu2memCon_addr<=lsu_queue[head][`RS_VJ]+lsu_queue[head][`RS_A];
                            lsu2memCon_rw<=`MEM_WRITE;
                            lsu2memCon_width<=2'd2;
                            lsu2memCon_value<=lsu_queue[head][`RS_VK];
                            lsu2memCon_ifSigned<=`FALSE;
                            busy<=`TRUE;
                            // end
                            // else begin
                            //     busy<=`FALSE;
                            //     lsu2memCon_enable<=`FALSE;
                            // end
                        end
                    endcase
                end
            end
            if(alu2lsu_bypass_enable) begin
                if(decoder2lsu_enable&&!full) begin
                    if(lsu_queue[tail][`RS_QJ]==alu2lsu_bypass_reorder&&!lsu_queue[tail][`RS_READY_1]) begin
                        lsu_queue[tail][`RS_VJ]<=alu2lsu_bypass_value;
                        lsu_queue[tail][`RS_READY_1]<=`TRUE;
                    end
                    if(lsu_queue[tail][`RS_QK]==alu2lsu_bypass_reorder&&!lsu_queue[tail][`RS_READY_2]) begin
                        lsu_queue[tail][`RS_VK]<=alu2lsu_bypass_value;
                        lsu_queue[tail][`RS_READY_2]<=`TRUE;
                    end
                end
                for(alu_i=head;alu_i!=tail;alu_i=alu_i==15?0:alu_i+1) begin
                    if(lsu_queue[alu_i][`RS_QJ]==alu2lsu_bypass_reorder&&!lsu_queue[i][`RS_READY_1]) begin
                        lsu_queue[alu_i][`RS_VJ]<=alu2lsu_bypass_value;
                        lsu_queue[alu_i][`RS_READY_1]<=`TRUE;
                    end
                    if(lsu_queue[alu_i][`RS_QK]==alu2lsu_bypass_reorder&&!lsu_queue[i][`RS_READY_2]) begin
                        lsu_queue[alu_i][`RS_VK]<=alu2lsu_bypass_value;
                        lsu_queue[alu_i][`RS_READY_2]<=`TRUE;
                    end
                end
            end
            if(rob2lsu_store_enable) begin
                if(decoder2lsu_enable&&!full) begin
                    if(lsu_queue[tail][`RS_REORDER]==rob2lsu_store_reorder/*&&is_store(input lsu_queue[tail][`RS_TYPE])*/) begin
                        store_enable_table[tail]<=`TRUE;
                    end
                end
                // if(tail!=0)
                for(rob_i=head;rob_i!=tail;rob_i=rob_i==15?0:rob_i+1)
                    if(lsu_queue[rob_i][`RS_REORDER]==rob2lsu_store_reorder/*&&is_store(input lsu_queue[rob_i][`RS_TYPE])*/) begin
                        store_enable_table[rob_i]<=`TRUE;
                    end
            end
        end
    end
end

function reg is_store(input [`INS_TYPE_WIDTH] type) ;
    begin
        is_store =  (type == `SB || type == `SH || type == `SW);
    end
endfunction


endmodule //lsu
