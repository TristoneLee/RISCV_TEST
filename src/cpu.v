// RISCV32I CPU top module
// port modification allowed for debugging purposes

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16] == 2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

`include "def.v"

module cpu(input wire clk_in,              // system clock signal
           input wire rst_in,              // reset signal
           input wire rdy_in,              // ready signal, pause cpu when low
           input wire[7:0] mem_din,        // data input bus
           output wire[7:0] mem_dout,      // data output bus
           output wire[31:0] mem_a,        // address bus (only 17:0 is used)
           output wire mem_wr,             // write/read signal (1 for write)
           input wire io_buffer_full,      // 1 if uart buffer is full
           output wire[31:0] dbgreg_dout); // cpu register output (debugging demo)

wire rs_full;
wire rob_full;
wire lsu_full;
wire flush_enable;
wire rob2decoder_full;
wire[`ADDR_WIDTH] rob2pc_pc;
wire rob2pc_enable;

wire decoder2rob_reserve_enable;
wire [`REG_WIDTH] decoder2rob_rs1_request;
wire [`REG_WIDTH] decoder2rob_rs2_request;
wire[`ROB_WIDTH] rob2decoder_rs1_rename;
wire[`ROB_WIDTH] rob2decoder_rs2_rename;
wire [`DATA_WIDTH]rob2decoder_rs1_value;
wire [`DATA_WIDTH]rob2decoder_rs2_value;
wire [`ROB_WIDTH] rob2decoder_reorder;
wire rob2decoder_rs1_if_rename;
wire rob2decoder_rs2_if_rename;
wire[`ROB_LINE_LENGTH-1:0] decoder2rob_robline;
wire [`REG_WIDTH] rob2reg_rs1_request;
wire [`REG_WIDTH] rob2reg_rs2_request;
wire[`DATA_WIDTH] reg2rob_rs1_value;
wire[`DATA_WIDTH] reg2rob_rs2_value;
wire[`DATA_WIDTH] reg2rob_rs1_rename;
wire[`DATA_WIDTH] reg2rob_rs2_rename;
wire reg2rob_rs1_if_rename;
wire reg2rob_rs2_if_rename;
wire rob2reg_commit_enable;
wire[`REG_WIDTH] rob2reg_commit_des;
wire [`DATA_WIDTH] rob2reg_commit_value;
wire [`ROB_WIDTH] rob2reg_commit_reorder;
wire alu2rob_enable;
wire[`ROB_WIDTH] alu2rob_reorder;
wire[`DATA_WIDTH] alu2rob_value;
wire[`ADDR_WIDTH] alu2rob_pc;
wire  lsu2rob_enable;
wire [`ROB_WIDTH]  lsu2rob_reorder;
wire [`DATA_WIDTH] lsu2rob_value;
wire [`ROB_WIDTH] rob2lsu_store_reorder;
wire rob2lsu_store_enable;

wire rob2reg_reserve_enable;
wire[`REG_WIDTH] rob2reg_reserve_rd;
wire[`ROB_WIDTH] rob2reg_reserve_reorder;

wire[`DATA_WIDTH] memCon2lsu_return;
wire memCon2lsu_enable;
wire[1:0] lsu2memCon_width;
wire[`ADDR_WIDTH] lsu2memCon_addr;
wire lsu2memCon_rw;
wire lsu2memCon_enable;
wire[`DATA_WIDTH] lsu2memCon_value;
wire lsu2memCon_ifSigned;
wire decoder2lsu_enable;
wire lsu2rs_bypass_enable;
wire[`ROB_WIDTH] lsu2rs_bypass_reorder;
wire[`DATA_WIDTH] lsu2rs_bypass_value;
wire alu2lsu_bypass_enable;
wire [`ROB_WIDTH] alu2lsu_bypass_reorder;
wire [`DATA_WIDTH] alu2lsu_bypass_value;

wire [`ADDR_WIDTH]fetch2iCache_address;
wire fetch2iCache_enable;
wire [`INS_WIDTH] iCache2fetch_return;
wire iCache2fetch_enable;
wire [`ADDR_WIDTH]iCache2fetch_pc;
wire [`ADDR_WIDTH]iCache2memCon_address;
wire iCache2memCon_enable;
wire [`INS_WIDTH] memCon2iCache_return;
wire memCon2iCache_enable;

wire fetch2decoder_enable;
wire[`INS_WIDTH] fetch2decoder_ins;
wire[`ADDR_WIDTH] fetch2decoder_pc;
wire decoder2fetch_enable;
wire decoder2rs_enable;
wire[`RS_LINE_LENGTH-1:0] decoder2rs_entry;
wire[`RS_LINE_LENGTH-1:0] decoder2lsu_entry;


wire rs2alu_enable;
wire[`DATA_WIDTH] rs2alu_rs1;
wire[`DATA_WIDTH] rs2alu_rs2;
wire[`DATA_WIDTH] rs2alu_imm;
wire[`INS_TYPE_WIDTH] rs2alu_ins_type;
wire[`ADDR_WIDTH] rs2alu_pc;
wire[`ROB_WIDTH] rs2alu_reorder;
wire alu2rs_bypass_enable;
wire[`ROB_WIDTH] alu2rs_bypass_reorder;
wire[`DATA_WIDTH] alu2rs_bypass_value;

wire[`ADDR_WIDTH] pc2fetch_next_pc;
wire fetch2pc_enable;

wire memCon2iCache_is_returning;
wire[`ADDR_WIDTH] rob2reg_commit_pc;

wire [`ROB_WIDTH] rob2reg_reorder;

FetchBuffer fetch_buffer(
                .iCache2fetch_enable(iCache2fetch_enable),
                .iCache2fetch_return(iCache2fetch_return),
                .iCache2fetch_pc(iCache2fetch_pc),
                .fetch2iCache_address(fetch2iCache_address),
                .fetch2iCache_enable(fetch2iCache_enable),
                .decoder2fetch_enable(decoder2fetch_enable),
                .fetch2decoder_ins(fetch2decoder_ins),
                .fetch2decoder_pc(fetch2decoder_pc),
                .fetch2decoder_enable(fetch2decoder_enable),
                .pc2fetch_next_pc(pc2fetch_next_pc),
                .fetch2pc_enable(fetch2pc_enable)
            );

Decoder decoder(
            .rdy_in(rdy_in),
            .rob_full(rob_full),
            .rs_full(rs_full),
            .lsu_full(lsu_full),
            .fetch2decoder_enable(fetch2decoder_enable),
            .fetch2decoder_ins(fetch2decoder_ins),
            .fetch2decoder_pc(fetch2decoder_pc),
            .decoder2fetch_enable(decoder2fetch_enable),
            .decoder2rob_rs1_request(decoder2rob_rs1_request),
            .decoder2rob_rs2_request(decoder2rob_rs2_request),
            .rob2decoder_rs1_if_rename(rob2decoder_rs1_if_rename),
            .rob2decoder_rs1_rename(rob2decoder_rs1_rename),
            .rob2decoder_rs1_value(rob2decoder_rs1_value),
            .rob2decoder_rs2_if_rename(rob2decoder_rs2_if_rename),
            .rob2decoder_rs2_rename(rob2decoder_rs2_rename),
            .rob2decoder_rs2_value(rob2decoder_rs2_value),
            .rob2decoder_reorder(rob2decoder_reorder),
            .decoder2rob_robline(decoder2rob_robline),
            .decoder2rob_enable(decoder2rob_enable),
            .decoder2lsu_enable(decoder2lsu_enable),
            .decoder2rs_enable(decoder2rs_enable),
            .decoder2lsu_entry(decoder2lsu_entry),
            .decoder2rs_entry(decoder2rs_entry),
            .decoder2rob_reserve_enable(decoder2rob_reserve_enable)
        );

ALU alu(
        .rs2alu_enable(rs2alu_enable),
        .rs2alu_rs1(rs2alu_rs1),
        .rs2alu_rs2(rs2alu_rs2),
        .rs2alu_imm(rs2alu_imm),
        .rs2alu_ins_type(rs2alu_ins_type),
        .rs2alu_pc(rs2alu_pc),
        .rs2alu_reorder(rs2alu_reorder),
        .alu2rs_bypass_enable(alu2rs_bypass_enable),
        .alu2rs_bypass_reorder(alu2rs_bypass_reorder),
        .alu2rs_bypass_value(alu2rs_bypass_value),
        .alu2rob_enable(alu2rob_enable),
        .alu2rob_reorder(alu2rob_reorder),
        .alu2rob_value(alu2rob_value),
        .alu2rob_pc(alu2rob_pc),
        .alu2lsu_bypass_enable(alu2lsu_bypass_enable),
        .alu2lsu_bypass_reorder(alu2lsu_bypass_reorder),
        .alu2lsu_bypass_value(alu2lsu_bypass_value)
    );

ICache i_cache(
           .clk_in(clk_in),
           .rst_in(rst_in),
           .rdy_in(rdy_in),
           .flush_enable(flush_enable),
           .fetch2iCache_address(fetch2iCache_address),
           .fetch2iCache_enable(fetch2iCache_enable),
           .iCache2fetch_return(iCache2fetch_return),
           .iCache2fetch_enable(iCache2fetch_enable),
           .iCache2fetch_pc(iCache2fetch_pc),
           .iCache2memCon_address(iCache2memCon_address),
           .iCache2memCon_enable(iCache2memCon_enable),
           .memCon2iCache_enable(memCon2iCache_enable),
           .memCon2iCache_return(memCon2iCache_return),
           .memCon2iCache_is_returning(memCon2iCache_is_returning)
       );

LoadStoreUnit load_store_unit(
                  .clk_in(clk_in),
                  .rst_in(rst_in),
                  .rdy_in(rdy_in),
                  .flush_enable(flush_enable),
                  .lsu_full(lsu_full),
                  .memCon2lsu_return(memCon2lsu_return),
                  .memCon2lsu_enable(memCon2lsu_enable),
                  .lsu2memCon_width(lsu2memCon_width),
                  .lsu2memCon_addr(lsu2memCon_addr),
                  .lsu2memCon_rw(lsu2memCon_rw),
                  .lsu2memCon_ifSigned(lsu2memCon_ifSigned),
                  .lsu2memCon_enable(lsu2memCon_enable),
                  .lsu2memCon_value(lsu2memCon_value),
                  .decoder2lsu_enable(decoder2lsu_enable),
                  .decoder2lsu_entry(decoder2lsu_entry),
                  .lsu2rs_bypass_enable(lsu2rs_bypass_enable),
                  .lsu2rs_bypass_reorder(lsu2rs_bypass_reorder),
                  .lsu2rs_bypass_value(lsu2rs_bypass_value),
                  .alu2lsu_bypass_enable(alu2lsu_bypass_enable),
                  .alu2lsu_bypass_reorder(alu2lsu_bypass_reorder),
                  .alu2lsu_bypass_value(alu2lsu_bypass_value),
                  .lsu2rob_enable(lsu2rob_enable),
                  .lsu2rob_reorder(lsu2rob_reorder),
                  .lsu2rob_value(lsu2rob_value),
                  .rob2lsu_store_enable(rob2lsu_store_enable),
                  .rob2lsu_store_reorder(rob2lsu_store_reorder)
              );

MemController mem_controller(
                  .clk_in(clk_in),
                  .rst_in(rst_in),
                  .rdy_in(rdy_in),
                  .memCon2iCache_enable(memCon2iCache_enable),
                  .memCon2iCache_return(memCon2iCache_return),
                  .iCache2memCon_address(iCache2memCon_address),
                  .iCache2memCon_enable(iCache2memCon_enable),
                  .memCon2lsu_return(memCon2lsu_return),
                  .memCon2lsu_enable(memCon2lsu_enable),
                  .lsu2memCon_width(lsu2memCon_width),
                  .lsu2memCon_addr(lsu2memCon_addr),
                  .lsu2memCon_rw(lsu2memCon_rw),
                  .lsu2memCon_ifSigned(lsu2memCon_ifSigned),
                  .lsu2memCon_enable(lsu2memCon_enable),
                  .lsu2memCon_value(lsu2memCon_value),
                  .mem2memCon_din(mem_din),
                  .memCon2mem_dout(mem_dout),
                  .memCon2mem_addr(mem_a),
                  .memCon2mem_rw_select(mem_wr),
                  .memCon2iCache_is_returning(memCon2iCache_is_returning)
              );

PC pc( .clk_in(clk_in),
       .rst_in(rst_in),
       .rdy_in(rdy_in),
       .rob2pc_pc(rob2pc_pc),
       .rob2pc_enable(rob2pc_enable),
       .fetch2pc_enable(fetch2pc_enable),
       .pc2fetch_next_pc(pc2fetch_next_pc)
     );

Registers registers(
              .clk_in(clk_in),
              .rst_in(rst_in),
              .rdy_in(rdy_in),
              .flush_enable(flush_enable),
              .rob2reg_rs1_request(rob2reg_rs1_request),
              .rob2reg_rs2_request(rob2reg_rs2_request),
              .reg2rob_rs1_if_rename(reg2rob_rs1_if_rename),
              .reg2rob_rs1_rename(reg2rob_rs1_rename),
              .reg2rob_rs1_value(reg2rob_rs1_value),
              .reg2rob_rs2_if_rename(reg2rob_rs2_if_rename),
              .reg2rob_rs2_rename(reg2rob_rs2_rename),
              .reg2rob_rs2_value(reg2rob_rs2_value),
              .rob2reg_reserve_enable(rob2reg_reserve_enable),
              .rob2reg_reserve_rd(rob2reg_reserve_rd),
              .rob2reg_reserve_reorder(rob2reg_reserve_reorder),
              .rob2reg_commit_enable(rob2reg_commit_enable),
              .rob2reg_commit_des(rob2reg_commit_des),
              .rob2reg_commit_reorder(rob2reg_commit_reorder),
              .rob2reg_commit_value(rob2reg_commit_value),
              .rob2reg_commit_pc(rob2reg_commit_pc),
              .rob2reg_reorder(rob2reg_reorder)
          );

ReorderBuffer reorder_buffer(
                  .clk_in(clk_in),
                  .rst_in(rst_in),
                  .rdy_in(rdy_in),
                  .flush_enable(flush_enable),
                  .rob_full(rob_full),
                  .rob2pc_enable(rob2pc_enable),
                  .rob2pc_pc(rob2pc_pc),
                  .decoder2rob_rs1_request(decoder2rob_rs1_request),
                  .decoder2rob_rs2_request(decoder2rob_rs2_request),
                  .rob2decoder_rs1_if_rename(rob2decoder_rs1_if_rename),
                  .rob2decoder_rs1_rename(rob2decoder_rs1_rename),
                  .rob2decoder_rs1_value(rob2decoder_rs1_value),
                  .rob2decoder_rs2_if_rename(rob2decoder_rs2_if_rename),
                  .rob2decoder_rs2_rename(rob2decoder_rs2_rename),
                  .rob2decoder_rs2_value(rob2decoder_rs2_value),
                  .rob2decoder_reorder(rob2decoder_reorder),
                  .decoder2rob_robline(decoder2rob_robline),
                  .decoder2rob_enable(decoder2rob_enable),
                  .rob2reg_rs1_request(rob2reg_rs1_request),
                  .rob2reg_rs2_request(rob2reg_rs2_request),
                  .reg2rob_rs1_if_rename(reg2rob_rs1_if_rename),
                  .reg2rob_rs1_rename(reg2rob_rs1_rename),
                  .reg2rob_rs1_value(reg2rob_rs1_value),
                  .reg2rob_rs2_if_rename(reg2rob_rs2_if_rename),
                  .reg2rob_rs2_rename(reg2rob_rs2_rename),
                  .reg2rob_rs2_value(reg2rob_rs2_value),
                  .rob2reg_reserve_enable(rob2reg_reserve_enable),
                  .rob2reg_reserve_rd(rob2reg_reserve_rd),
                  .rob2reg_reserve_reorder(rob2reg_reserve_reorder),
                  .rob2reg_commit_des(rob2reg_commit_des),
                  .rob2reg_commit_enable(rob2reg_commit_enable),
                  .rob2reg_commit_reorder(rob2reg_commit_reorder),
                  .rob2reg_commit_value(rob2reg_commit_value),
                  .alu2rob_enable(alu2rob_enable),
                  .alu2rob_pc(alu2rob_pc),
                  .alu2rob_reorder(alu2rob_reorder),
                  .alu2rob_value(alu2rob_value),
                  .lsu2rob_enable(lsu2rob_enable),
                  .lsu2rob_reorder(lsu2rob_reorder),
                  .lsu2rob_value(lsu2rob_value),
                  .rob2lsu_store_enable(rob2lsu_store_enable),
                  .rob2lsu_store_reorder(rob2lsu_store_reorder),
                  .rob2reg_commit_pc(rob2reg_commit_pc),
                  .decoder2rob_reserve_enable(decoder2rob_reserve_enable),
                  .rob2reg_reorder(rob2reg_reorder)
              );

ReservationStation reservation_station(
                       .clk_in(clk_in),
                       .rst_in(rst_in),
                       .rdy_in(rdy_in),
                       .flush_enable(flush_enable),
                       .rs_full(rs_full),
                       .decoder2rs_enable(decoder2rs_enable),
                       .decoder2rs_entry(decoder2rs_entry),
                       .rs2alu_enable(rs2alu_enable),
                       .rs2alu_rs1(rs2alu_rs1),
                       .rs2alu_rs2(rs2alu_rs2),
                       .rs2alu_imm(rs2alu_imm),
                       .rs2alu_ins_type(rs2alu_ins_type),
                       .rs2alu_pc(rs2alu_pc),
                       .rs2alu_reorder(rs2alu_reorder),
                       .alu2rs_bypass_enable(alu2rs_bypass_enable),
                       .alu2rs_bypass_reorder(alu2rs_bypass_reorder),
                       .alu2rs_bypass_value(alu2rs_bypass_value),
                       .lsu2rs_bypass_enable(lsu2rs_bypass_enable),
                       .lsu2rs_bypass_reorder(lsu2rs_bypass_reorder),
                       .lsu2rs_bypass_value(lsu2rs_bypass_value)
                   );

endmodule
