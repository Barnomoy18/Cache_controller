`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.11.2026 11:38:27
// Design Name: 
// Module Name: cache_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// =====================================================================
// File : cache_top.v
// Description : Top-level wrapper connecting the CPU-side interface,
// the cache controller (FSM), and the cache memory
// array (tag / data / valid / dirty storage) together.
// Author : VLSI Mini-Project - Direct Mapped Write-Back Cache
// =====================================================================
module cache_top #(
parameter ADDR_WIDTH = 32,
parameter DATA_WIDTH = 32,
parameter INDEX_WIDTH = 6, // 64 cache lines
parameter OFFSET_WIDTH = 2, // 4 words per block (block size = 16B)
parameter TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - 2
)(
input wire clk,
input wire rst_n,
// CPU <-> Cache interface
input wire cpu_req, // CPU issues a request
input wire cpu_we, // 1 = write, 0 = read
input wire [ADDR_WIDTH-1:0] cpu_addr,
input wire [DATA_WIDTH-1:0] cpu_wdata,
output wire [DATA_WIDTH-1:0] cpu_rdata,
output wire cpu_ready, // request completed
output wire cpu_hit, // pulse: hit indicator
// Cache <-> Main Memory interface (burst word access)
output wire mem_req,
output wire mem_we,
output wire [ADDR_WIDTH-1:0] mem_addr,
output wire [DATA_WIDTH-1:0] mem_wdata,
input wire [DATA_WIDTH-1:0] mem_rdata,
input wire mem_ready
);
// Internal wires between controller (FSM) and memory array
wire tag_wr_en;
wire data_wr_en;
wire valid_wr_en;
wire dirty_wr_en;
wire dirty_wr_val;
wire [OFFSET_WIDTH-1:0] word_sel;
wire [TAG_WIDTH-1:0] tag_in;
wire [TAG_WIDTH-1:0] tag_out;
wire valid_out;
wire dirty_out;
wire [DATA_WIDTH-1:0] line_wdata;
wire [DATA_WIDTH-1:0] line_rdata;
wire [(DATA_WIDTH*4)-1:0] block_wdata;
wire [(DATA_WIDTH*4)-1:0] block_rdata;
wire block_wr_en;
wire word_wr_en;
// index/offset that actually drive the cache memory array come from
// the controller's LATCHED address (addr_r), not raw cpu_addr, so
// they stay stable for the whole multi-cycle transaction.
wire [INDEX_WIDTH-1:0] index;
wire [OFFSET_WIDTH-1:0] offset;
cache_controller #(
.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
.INDEX_WIDTH(INDEX_WIDTH), .OFFSET_WIDTH(OFFSET_WIDTH),
.TAG_WIDTH(TAG_WIDTH)
) u_ctrl (
.clk (clk),
.rst_n (rst_n),
.cpu_req (cpu_req),
.cpu_we (cpu_we),
.cpu_addr (cpu_addr),
.cpu_wdata (cpu_wdata),
.cpu_rdata (cpu_rdata),
.cpu_ready (cpu_ready),
.cpu_hit (cpu_hit),
.mem_req (mem_req),
.mem_we (mem_we),
.mem_addr (mem_addr),
.mem_wdata (mem_wdata),
.mem_rdata (mem_rdata),
.mem_ready (mem_ready),
.tag_out (tag_out),
.valid_out (valid_out),
.dirty_out (dirty_out),
.tag_in (tag_in),
.tag_wr_en (tag_wr_en),
.valid_wr_en (valid_wr_en),
.dirty_wr_en (dirty_wr_en),
.dirty_wr_val (dirty_wr_val),
.block_wdata (block_wdata),
.block_rdata (block_rdata),
.block_wr_en (block_wr_en),
.line_wdata (line_wdata),
.word_wr_en (word_wr_en),
.line_rdata (line_rdata),
.index_o (index),
.word_sel_o (offset)
);
cache_mem #(
.DATA_WIDTH(DATA_WIDTH), .INDEX_WIDTH(INDEX_WIDTH),
.TAG_WIDTH(TAG_WIDTH)
) u_mem (
.clk (clk),
.rst_n (rst_n),
.index (index),
.offset (offset),
.tag_in (tag_in),
.tag_wr_en (tag_wr_en),
.valid_wr_en (valid_wr_en),
.dirty_wr_en (dirty_wr_en),
.dirty_wr_val (dirty_wr_val),
.block_wdata (block_wdata),
.block_wr_en (block_wr_en),
.block_rdata (block_rdata),
.line_wdata (line_wdata),
.word_wr_en (word_wr_en),
.line_rdata (line_rdata),
.tag_out (tag_out),
.valid_out (valid_out),
.dirty_out (dirty_out)
);
endmodule
