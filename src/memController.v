`include "def.v"

module MemController
       (input wire clk_in,
        input wire rst_in,
        input wire rdy_in,
        //control signal

        output reg memCon2iCache_enable,
        output reg[`WORD_WIDTH] memCon2iCache_return,
        output reg memCon2iCache_is_returning,
        input wire iCache2memCon_enable,
        input wire [`ADDR_WIDTH] iCache2memCon_address,
        //with iCache

        output reg[`WORD_WIDTH] memCon2lsu_return,
        output reg memCon2lsu_enable,
        input wire[1:0] lsu2memCon_width,
        input wire [`ADDR_WIDTH] lsu2memCon_addr,
        input wire lsu2memCon_rw,
        input wire lsu2memCon_ifSigned,
        input wire lsu2memCon_enable,
        input wire [`DATA_WIDTH] lsu2memCon_value,
        //with lsu

        input wire [`MEM_WIDTH] mem2memCon_din,
        output reg [`MEM_WIDTH] memCon2mem_dout,
        output reg [`ADDR_WIDTH] memCon2mem_addr,
        output reg memCon2mem_rw_select
        //with memory
       );

reg ram_en;
reg[2:0] count_down;
reg[`DATA_WIDTH] io_buffer;
reg[`MEM_COMMAND_LENGTH-1:0] current_command;
wire current_rw=current_command[`MEM_COMMAND_RW];
wire[1:0] current_width=current_command[`MEM_COMMAND_WIDTH];
wire [`ADDR_WIDTH]current_addr=current_command[`MEM_COMMAND_ADDR];
wire current_sign=current_command[`MEM_COMMAND_SIGN];
wire current_src=current_command[`MEM_COMMAND_SRC];

initial begin
    current_command <=0;
    count_down <=0;
    io_buffer <=`ZERO_DATA;
    memCon2mem_rw_select<=`MEM_READ;
    memCon2mem_addr <=`ZERO_ADDR;
    memCon2mem_dout <=`ZERO_BYTE;
    memCon2iCache_return <=`ZERO_DATA;
    memCon2iCache_enable <=`FALSE;
    memCon2iCache_is_returning<=`FALSE;
    memCon2lsu_enable <=`FALSE;
    memCon2lsu_return <=`ZERO_DATA;
end

always @(posedge clk_in) begin
    if (rst_in) begin
        current_command <= `ZERO_MEM_COMMAND;
        io_buffer <=`ZERO_DATA;
        memCon2mem_rw_select<=`MEM_READ;
        memCon2mem_addr <=`ZERO_ADDR;
        memCon2mem_dout <=`ZERO_BYTE;
        memCon2iCache_return <=`ZERO_DATA;
        memCon2iCache_enable <=`FALSE;
        memCon2iCache_is_returning<=`FALSE;
        memCon2lsu_enable <=`FALSE;
        memCon2lsu_return <=`ZERO_DATA;
    end
    else if (rdy_in) begin
        if(memCon2iCache_is_returning==`TRUE) begin
            memCon2iCache_is_returning<=`FALSE;
        end
        if(memCon2iCache_enable==`TRUE) begin
            memCon2iCache_enable<=`FALSE;
        end
        if(memCon2lsu_enable==`TRUE)begin
          memCon2lsu_enable<=`FALSE;
        end
        case (count_down)
            3'd0: begin
                if (lsu2memCon_enable&&!memCon2lsu_enable) begin
                    current_command[`MEM_COMMAND_ADDR]  <= lsu2memCon_addr;
                    current_command[`MEM_COMMAND_WIDTH] <= lsu2memCon_width;
                    current_command[`MEM_COMMAND_SRC]    <= `SRC_LSU;
                    current_command[`MEM_COMMAND_RW]     <= lsu2memCon_rw;
                    current_command[`MEM_COMMAND_SIGN]   <= lsu2memCon_ifSigned;
                    memCon2mem_rw_select<=lsu2memCon_rw;
                    if(lsu2memCon_rw==`MEM_WRITE) begin
                        io_buffer<=lsu2memCon_value;
                    end
                    if(lsu2memCon_width==`WIDTH_WORD) begin
                        count_down<=3'd5;
                        memCon2mem_addr<=lsu2memCon_addr+3;
                        if(lsu2memCon_rw<=`MEM_WRITE) begin
                            memCon2mem_dout<=lsu2memCon_value[31:24];
                        end
                    end
                    else if(lsu2memCon_width ==`WIDTH_HALF) begin
                        count_down<=3'd3;
                        memCon2mem_addr<=lsu2memCon_addr+1;
                        if(lsu2memCon_rw<=`MEM_WRITE) begin
                            memCon2mem_dout<=lsu2memCon_value[15:8];
                        end
                    end
                    else if(lsu2memCon_width ==`WIDTH_BYTE) begin
                        count_down<=3'd2;
                        memCon2mem_addr<=lsu2memCon_addr;
                        if(memCon2mem_rw_select<=`MEM_WRITE) begin
                            memCon2mem_dout<=lsu2memCon_value[7:0];
                        end
                    end
                end
                else if (iCache2memCon_enable) begin
                    current_command[`MEM_COMMAND_ADDR]    <= iCache2memCon_address;
                    current_command[`MEM_COMMAND_WIDTH]   <=  `WIDTH_WORD;
                    current_command[`MEM_COMMAND_SRC]     <= `SRC_ICACHE;
                    current_command[`MEM_COMMAND_RW]      <= `MEM_READ;
                    count_down                            <= 3'd5;
                    current_command[`MEM_COMMAND_SIGN]    <= `FALSE;
                    memCon2mem_addr<=iCache2memCon_address+3;
                    memCon2mem_rw_select<=`MEM_READ;
                end
            end
            3'd1: begin
                count_down<=3'd0;
                if(current_rw==`MEM_READ) begin
                    memCon2mem_rw_select<=`MEM_READ;
                    if(current_width==`WIDTH_BYTE) begin
                        memCon2lsu_enable<=`TRUE;
                        if(current_sign) begin
                            memCon2lsu_return<={{24{mem2memCon_din[7]}},mem2memCon_din};
                        end
                        else begin
                            memCon2lsu_return<={{24{1'd0}},mem2memCon_din};
                        end
                    end
                    else if (current_width==`WIDTH_HALF) begin
                        memCon2lsu_enable<=`TRUE;
                        if(current_sign) begin
                            memCon2lsu_return<={{16{io_buffer[15]}},io_buffer[15:8],mem2memCon_din};
                        end
                        else begin
                            memCon2lsu_return<={{16{1'd0}},io_buffer[15:8],mem2memCon_din};
                        end
                    end
                    else if(current_width==`WIDTH_WORD) begin
                        if(current_src==`SRC_LSU) begin
                            memCon2lsu_return[31:8] <=io_buffer[31:8];
                            memCon2lsu_return[7:0]<=mem2memCon_din;
                            memCon2lsu_enable <= `TRUE;
                            io_buffer            <= `ZERO_DATA;
                        end
                        else begin
                            memCon2iCache_return[31:8] <=io_buffer[31:8];
                            memCon2iCache_return[7:0]<=mem2memCon_din;
                            memCon2iCache_enable<= `TRUE;
                            io_buffer            <= `ZERO_DATA;
                        end
                    end
                end
                else begin
                    memCon2lsu_enable<=`TRUE;
                    memCon2mem_rw_select<=`MEM_READ;
                end
            end
            3'd2: begin
                count_down<=3'd1;
                if(current_rw==`MEM_READ) begin
                    io_buffer[15:8]<=mem2memCon_din;
                    if(current_src==`SRC_ICACHE) begin
                        memCon2iCache_is_returning<=`TRUE;
                    end
                end
                else begin
                    memCon2mem_rw_select<=`MEM_READ;
                end
            end
            3'd3: begin
                count_down<=3'd2;
                if(current_rw==`MEM_READ) begin
                    memCon2mem_rw_select<=`MEM_READ;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR];
                    io_buffer[23:16]<=mem2memCon_din;
                end
                else begin
                    memCon2mem_rw_select<=`MEM_WRITE;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR];
                    memCon2mem_dout<=io_buffer[7:0];
                end
            end
            3'd4: begin
                count_down<=3'd3;
                if(current_rw==`MEM_READ) begin
                    memCon2mem_rw_select<=`MEM_READ;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR]+1;
                    io_buffer[31:24]<=mem2memCon_din;
                end
                else begin
                    memCon2mem_rw_select<=`MEM_WRITE;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR]+1;
                    memCon2mem_dout<=io_buffer[15:8];
                end
            end
            3'd5: begin
                count_down<=3'd4;
                if(current_rw==`MEM_READ) begin
                    memCon2mem_rw_select<=`MEM_READ;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR]+2;
                end
                else begin
                    memCon2mem_rw_select<=`MEM_WRITE;
                    memCon2mem_addr<=current_command[`MEM_COMMAND_ADDR]+2;
                    memCon2mem_dout<=io_buffer[23:16];
                end
            end
        endcase
    end
end


endmodule
