`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.11.2026 11:46:27
// Design Name: 
// Module Name: cache_mem
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


module cache_mem #(
    parameter DATA_WIDTH  = 32,
    parameter INDEX_WIDTH = 6,
    parameter TAG_WIDTH   = 24,
    parameter NUM_LINES   = (1 << INDEX_WIDTH)
)(
    input  wire                        clk,
    input  wire                        rst_n,

    input  wire [INDEX_WIDTH-1:0]      index,
    input  wire [1:0]                  offset,

    input  wire [TAG_WIDTH-1:0]        tag_in,
    input  wire                        tag_wr_en,
    input  wire                        valid_wr_en,
    input  wire                        dirty_wr_en,
    input  wire                        dirty_wr_val,

    input  wire [(DATA_WIDTH*4)-1:0]   block_wdata,
    input  wire                        block_wr_en,
    output wire [(DATA_WIDTH*4)-1:0]   block_rdata,

    input  wire [DATA_WIDTH-1:0]       line_wdata,
    input  wire                        word_wr_en,
    output wire [DATA_WIDTH-1:0]       line_rdata,

    output wire [TAG_WIDTH-1:0]        tag_out,
    output wire                        valid_out,
    output wire                        dirty_out
);

    reg [TAG_WIDTH-1:0]      tag_array   [0:NUM_LINES-1];
    reg                      valid_array [0:NUM_LINES-1];
    reg                      dirty_array [0:NUM_LINES-1];
    reg [(DATA_WIDTH*4)-1:0] data_array  [0:NUM_LINES-1];

    integer i;

    assign tag_out   = tag_array[index];
    assign valid_out = valid_array[index];
    assign dirty_out = dirty_array[index];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            if (tag_wr_en)   tag_array[index]   <= tag_in;
            if (valid_wr_en) valid_array[index] <= 1'b1;
            if (dirty_wr_en) dirty_array[index] <= dirty_wr_val;
        end
    end

    always @(posedge clk) begin
        if (block_wr_en)
            data_array[index] <= block_wdata;
        else if (word_wr_en)
            data_array[index][offset*DATA_WIDTH +: DATA_WIDTH] <= line_wdata;
    end

    assign block_rdata = data_array[index];
    assign line_rdata  = data_array[index][offset*DATA_WIDTH +: DATA_WIDTH];

endmodule