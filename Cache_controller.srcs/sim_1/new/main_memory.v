`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.11.2026 19:51:12
// Design Name: 
// Module Name: main_memory
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
// File : main_memory.v
// Description : Simple behavioral main-memory model with a fixed
// 2-cycle access latency, used to exercise the cache
// controller's ALLOCATE / WRITE_BACK burst logic.
// =====================================================================
module main_memory #(
parameter ADDR_WIDTH = 32,
parameter DATA_WIDTH = 32,
parameter MEM_WORDS = 4096,
parameter LATENCY = 2
)(
input wire clk,
input wire rst_n,
input wire mem_req,
input wire mem_we,
input wire [ADDR_WIDTH-1:0] mem_addr,
input wire [DATA_WIDTH-1:0] mem_wdata,
output reg [DATA_WIDTH-1:0] mem_rdata,
output reg mem_ready
);
reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
reg [3:0] wait_cnt;
reg busy;
integer k;
initial begin
// Preload with a simple known pattern: mem[addr_word] = addr_word*4
for (k = 0; k < MEM_WORDS; k = k + 1)
mem[k] = k * 4;
end
wire [ADDR_WIDTH-3:0] word_addr = mem_addr[ADDR_WIDTH-1:2];
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
mem_ready <= 1'b0;
busy <= 1'b0;
wait_cnt <= 4'd0;
mem_rdata <= {DATA_WIDTH{1'b0}};
end else begin
mem_ready <= 1'b0;
if (mem_req && !busy) begin
busy <= 1'b1;
wait_cnt <= LATENCY;
end else if (busy) begin
if (wait_cnt == 0) begin
if (mem_we)
mem[word_addr] <= mem_wdata;
else
mem_rdata <= mem[word_addr];
mem_ready <= 1'b1;
busy <= 1'b0;
end else begin
wait_cnt <= wait_cnt - 1'b1;
end
end
end
end
endmodule

