`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.11.2026 19:48:13
// Design Name: 
// Module Name: tb_cache
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


module tb_cache;
localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;
reg clk = 0;
reg rst_n;
reg cpu_req;
reg cpu_we;
reg [ADDR_WIDTH-1:0] cpu_addr;
reg [DATA_WIDTH-1:0] cpu_wdata;
wire [DATA_WIDTH-1:0] cpu_rdata;
wire cpu_ready;
wire cpu_hit;
wire mem_req;
wire mem_we;
wire [ADDR_WIDTH-1:0] mem_addr;
wire [DATA_WIDTH-1:0] mem_wdata;
wire [DATA_WIDTH-1:0] mem_rdata;
wire mem_ready;
integer errors = 0;
integer test_num = 0;
// ------------- Clock generation: 100 MHz -------------
always #5 clk = ~clk;
// ------------- DUT -------------
cache_top #(
.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
) dut (
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
.mem_ready (mem_ready)
);
main_memory #(
.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
) mem (
.clk (clk),
.rst_n (rst_n),
.mem_req (mem_req),
.mem_we (mem_we),
.mem_addr (mem_addr),
.mem_wdata (mem_wdata),
.mem_rdata (mem_rdata),
.mem_ready (mem_ready)
);
// ------------- Task: drive one CPU transaction -------------
task do_access(
input [ADDR_WIDTH-1:0] addr,
input we,
input [DATA_WIDTH-1:0] wdata,
input expect_hit,
input [DATA_WIDTH-1:0] expect_rdata,
input check_rdata
);
begin
test_num = test_num + 1;
@(negedge clk);
cpu_req = 1'b1;
cpu_we = we;
cpu_addr = addr;
cpu_wdata = wdata;
@(negedge clk);
cpu_req = 1'b0;
wait (cpu_ready == 1'b1);
$display("[T%0d] t=%0t addr=%h we=%b hit=%b rdata=%h",
test_num, $time, addr, we, cpu_hit, cpu_rdata);
if (cpu_hit !== expect_hit) begin
$display(" ERROR: expected hit=%b, got hit=%b", expect_hit, cpu_hit);
errors = errors + 1;
end
if (check_rdata && !we && cpu_rdata !== expect_rdata) begin
$display(" ERROR: expected rdata=%h, got rdata=%h", expect_rdata, cpu_rdata);
errors = errors + 1;
end
@(negedge clk);
end
endtask
initial begin
$dumpfile("cache_wave.vcd");
$dumpvars(0, tb_cache);
cpu_req = 0; cpu_we = 0; cpu_addr = 0; cpu_wdata = 0;
rst_n = 0;
repeat (3) @(negedge clk);
rst_n = 1;
repeat (2) @(negedge clk);
// Test 1: cold read miss on address 0x00000000 -> allocates line,
// memory model preloaded mem[word_addr] = word_addr*4 = 0
do_access(32'h0000_0000, 1'b0, 32'h0, 1'b0, 32'h0000_0000, 1'b1);
// Test 2: read hit on the same address (line now resident)
do_access(32'h0000_0000, 1'b0, 32'h0, 1'b1, 32'h0000_0000, 1'b1);
// Test 3: write hit on word 1 of the same line -> sets dirty bit
do_access(32'h0000_0004, 1'b1, 32'hDEAD_BEEF, 1'b1, 32'h0, 1'b0);
// Test 4: read back the just-written word -> hit, data matches
do_access(32'h0000_0004, 1'b0, 32'h0, 1'b1, 32'hDEAD_BEEF, 1'b1);
// Test 5: conflict miss - address maps to same index, different tag.
// Block size = 16 bytes (4 words), index width = 6 bits
// occupying addr[9:4] -> the index repeats every 1024
// bytes, so 0x400 aliases to the same line as 0x000 but
// carries a different tag. This forces
// WB_CHECK -> WRITE_BACK (dirty) -> ALLOCATE.
do_access(32'h0000_0400, 1'b0, 32'h0, 1'b0, 32'h0000_0400, 1'b1);
// Test 6: re-access original line's evicted address -> compulsory
// miss again (line was evicted); confirms write-back of
// dirty data preserved DEAD_BEEF in main memory
do_access(32'h0000_0004, 1'b0, 32'h0, 1'b0, 32'hDEAD_BEEF, 1'b1);
repeat (5) @(negedge clk);
if (errors == 0)
$display("\n==== ALL TESTS PASSED (%0d checks) ====\n", test_num);
else
$display("\n==== %0d ERROR(S) FOUND across %0d tests ====\n", errors, test_num);
$finish;
end
// Safety timeout
initial begin
#20000;
$display("ERROR: TESTBENCH TIMEOUT");
$finish;
end
endmodule
