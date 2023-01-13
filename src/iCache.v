`include "def.v"

module ICache(input wire clk_in,
              input wire rst_in,
              input wire rdy_in,
              input wire flush_enable,

              input wire [`ADDR_WIDTH]fetch2iCache_address,
              input wire fetch2iCache_enable,
              output reg [`INS_WIDTH] iCache2fetch_return,
              output reg iCache2fetch_enable,
              output reg [`ADDR_WIDTH]iCache2fetch_pc,

              output reg [`ADDR_WIDTH]iCache2memCon_address,
              output reg iCache2memCon_enable,
              input wire [`INS_WIDTH] memCon2iCache_return,
              input wire memCon2iCache_enable,
              input wire memCon2iCache_is_returning
             );

reg[`CACHE_TAG_LENGTH:0] index_array[`CACHE_SET_COUNT-1:0]; //first bit is valid bit
reg[`CACHE_LINE_SIZE-1:0] data_array[`CACHE_SET_COUNT-1:0];
reg[`ADDR_WIDTH] current_ins;
wire[`CACHE_INDEX_WIDTH] current_index = current_ins[`CACHE_INDEX_WIDTH];
wire[`CACHE_INDEX_WIDTH] fetch2iCache_index=fetch2iCache_address[`CACHE_INDEX_WIDTH];
wire[25:0] fetch2iCache_tag=fetch2iCache_address[`CACHE_TAG_WIDTH];
reg if_stalling;
reg if_idle;
reg if_ignore;

integer i,j,index;

initial begin
    if_stalling <=`FALSE;
    if_idle<=`FALSE;
    current_ins <=`ZERO_ADDR;
    iCache2fetch_enable<=`FALSE;
    iCache2memCon_enable<=`FALSE;
    iCache2memCon_address<=`ZERO_ADDR;
    iCache2fetch_return<=`ZERO_DATA;
    iCache2fetch_pc<=`ZERO_ADDR;
    for(i = 0;i<`CACHE_SET_COUNT;i = i+1) begin
        index_array[i] <= 0;
        data_array[i]<=`ZERO_DATA;
    end
end

always @(posedge clk_in) begin
    if (rst_in) begin
        if_stalling <=`FALSE;
        current_ins <=`ZERO_ADDR;
        if_idle<=`FALSE;
        iCache2fetch_enable<=`FALSE;
        iCache2memCon_enable<=`FALSE;
        if_ignore<=`FALSE;
    end
    else if (rdy_in) begin
        if(flush_enable) begin
            if_stalling <=`FALSE;
            iCache2fetch_enable<=`FALSE;
            iCache2memCon_enable<=`FALSE;
            if(if_stalling&&!memCon2iCache_enable)
                if_ignore<=`TRUE;
        end
        else begin
            if (fetch2iCache_enable == `TRUE) begin
                if(if_idle) begin
                    if_idle<=`FALSE;
                    iCache2fetch_enable<=`FALSE;
                    iCache2memCon_enable<=`FALSE;
                end
                else if(!if_stalling) begin
                    current_ins <= fetch2iCache_address;
                    if (index_array[fetch2iCache_index][`CACHE_TAG_LENGTH]&&index_array[fetch2iCache_index][`CACHE_TAG_LENGTH-1:0] == fetch2iCache_tag) begin
                        iCache2fetch_return <= data_array[fetch2iCache_index];
                        iCache2fetch_enable <= `TRUE;
                        iCache2fetch_pc     <= fetch2iCache_address;
                        iCache2memCon_enable<=`FALSE;
                        if_idle<=`TRUE;
                    end
                    else  begin
                        iCache2memCon_enable  <=`TRUE;
                        iCache2memCon_address <=fetch2iCache_address;
                        if_stalling           <=`TRUE;
                        iCache2fetch_enable   <=`FALSE;
                    end
                end
                else begin
                    if(memCon2iCache_is_returning&&!if_ignore) begin
                        iCache2memCon_enable<=`FALSE;
                    end
                    if(memCon2iCache_enable) begin
                        if(!if_ignore) begin
                            iCache2fetch_enable <=`TRUE;
                            iCache2fetch_pc     <=current_ins;
                            iCache2fetch_return <=memCon2iCache_return;
                            if_stalling         <=`FALSE;
                            index_array[current_index]<={`FALSE,current_ins[`CACHE_TAG_WIDTH]};
                            data_array[current_index]<=memCon2iCache_return;
                            if_idle<=`TRUE;
                        end
                        else begin
                            if_ignore<=`FALSE;
                        end
                    end
                end
            end
        end
    end
end
endmodule
