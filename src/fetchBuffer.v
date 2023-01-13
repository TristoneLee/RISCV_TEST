`include "def.v"

module FetchBuffer(
                   input wire iCache2fetch_enable,
                   input wire [`INS_WIDTH] iCache2fetch_return,
                   input wire [`ADDR_WIDTH] iCache2fetch_pc,
                   output wire fetch2iCache_enable,
                   output wire [`ADDR_WIDTH]fetch2iCache_address,

                   input wire decoder2fetch_enable,
                   output wire[`INS_WIDTH] fetch2decoder_ins,
                   output wire[`ADDR_WIDTH] fetch2decoder_pc,
                   output wire fetch2decoder_enable,

                   input wire[`ADDR_WIDTH] pc2fetch_next_pc,
                   output wire fetch2pc_enable
                  );

assign fetch2iCache_enable=decoder2fetch_enable;
assign fetch2iCache_address=pc2fetch_next_pc;

assign fetch2decoder_pc=iCache2fetch_pc;
assign fetch2decoder_enable=iCache2fetch_enable;
assign fetch2decoder_ins=iCache2fetch_return;

assign fetch2pc_enable=decoder2fetch_enable&&iCache2fetch_enable;

endmodule
