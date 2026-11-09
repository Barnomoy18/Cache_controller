
`timescale 1ns / 1ps

module cache_controller #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter INDEX_WIDTH = 6,
    parameter OFFSET_WIDTH = 2,
    parameter TAG_WIDTH = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - 2
)(
    input wire clk,
    input wire rst_n,

    // CPU Interface
    input wire cpu_req,
    input wire cpu_we,
    input wire [ADDR_WIDTH-1:0] cpu_addr,
    input wire [DATA_WIDTH-1:0] cpu_wdata,

    output wire [DATA_WIDTH-1:0] cpu_rdata,
    output wire cpu_ready,
    output reg cpu_hit,

    // Main Memory Interface
    output reg mem_req,
    output reg mem_we,
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_wdata,

    input wire [DATA_WIDTH-1:0] mem_rdata,
    input wire mem_ready,

    // Cache Memory Array Interface
    input wire [TAG_WIDTH-1:0] tag_out,
    input wire valid_out,
    input wire dirty_out,

    output reg [TAG_WIDTH-1:0] tag_in,
    output reg tag_wr_en,
    output reg valid_wr_en,
    output reg dirty_wr_en,
    output reg dirty_wr_val,

    output reg [(DATA_WIDTH*4)-1:0] block_wdata,
    input wire [(DATA_WIDTH*4)-1:0] block_rdata,
    output reg block_wr_en,

    output reg [DATA_WIDTH-1:0] line_wdata,
    output reg word_wr_en,
    input wire [DATA_WIDTH-1:0] line_rdata,

    // Index and Word Select
    output wire [INDEX_WIDTH-1:0] index_o,
    output wire [OFFSET_WIDTH-1:0] word_sel_o
);

    // ============================================================
    // Parameters and FSM States
    // ============================================================

    localparam BYTE_W = 2;

    localparam IDLE       = 3'd0;
    localparam COMPARE    = 3'd1;
    localparam WB_CHECK   = 3'd2;
    localparam WRITE_BACK = 3'd3;
    localparam ALLOCATE   = 3'd4;
    localparam UPDATE     = 3'd5;
    localparam DONE       = 3'd6;

    reg [2:0] state, next_state;

    // ============================================================
    // Latched CPU Request Information
    // ============================================================

    reg [ADDR_WIDTH-1:0] addr_r;
    reg [DATA_WIDTH-1:0] wdata_r;
    reg we_r;

    reg [1:0] burst_cnt;

    reg [(DATA_WIDTH*3)-1:0] fetch_buf;

    // ============================================================
    // Address Decoding
    // ============================================================

    wire [OFFSET_WIDTH-1:0] offset;

    wire [INDEX_WIDTH-1:0] index;

    wire [TAG_WIDTH-1:0] tag;

    wire [ADDR_WIDTH-1:0] block_base_addr;

    wire [ADDR_WIDTH-1:0] wb_addr;

    assign offset = addr_r[OFFSET_WIDTH+BYTE_W-1:BYTE_W];

    assign index =
        addr_r[INDEX_WIDTH+OFFSET_WIDTH+BYTE_W-1:OFFSET_WIDTH+BYTE_W];

    assign tag =
        addr_r[ADDR_WIDTH-1:INDEX_WIDTH+OFFSET_WIDTH+BYTE_W];

    assign block_base_addr =
        {addr_r[ADDR_WIDTH-1:OFFSET_WIDTH+BYTE_W],
         {(OFFSET_WIDTH+BYTE_W){1'b0}}};

    assign wb_addr =
        {tag_out, index, {(OFFSET_WIDTH+BYTE_W){1'b0}}};

    assign index_o = index;

    assign word_sel_o = offset;

    // ============================================================
    // Hit and Burst Detection
    // ============================================================

    wire burst_last;

    wire hit;

    assign burst_last = (burst_cnt == 2'd3);

    assign hit = valid_out && (tag_out == tag);

    // ============================================================
    // 1. FSM State Register
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            state <= IDLE;

        else
            state <= next_state;

    end

    // ============================================================
    // 2. Next State Logic
    // ============================================================

    always @(*) begin

        case (state)

            IDLE:
                next_state = cpu_req ? COMPARE : IDLE;

            COMPARE:
                next_state = hit ? UPDATE : WB_CHECK;

            WB_CHECK:
                next_state = (valid_out && dirty_out) ?
                             WRITE_BACK : ALLOCATE;

            WRITE_BACK:
                next_state = (mem_ready && burst_last) ?
                             ALLOCATE : WRITE_BACK;

            ALLOCATE:
                next_state = (mem_ready && burst_last) ?
                             UPDATE : ALLOCATE;

            UPDATE:
                next_state = DONE;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;

        endcase

    end

    // ============================================================
    // 3. Combinational Control and Datapath Outputs
    // ============================================================

    always @(*) begin

        // Default values

        mem_req = 1'b0;
        mem_we = 1'b0;

        mem_addr = {ADDR_WIDTH{1'b0}};
        mem_wdata = {DATA_WIDTH{1'b0}};

        tag_in = tag;

        tag_wr_en = 1'b0;
        valid_wr_en = 1'b0;

        dirty_wr_en = 1'b0;
        dirty_wr_val = 1'b0;

        block_wr_en = 1'b0;

        block_wdata = {mem_rdata, fetch_buf};

        word_wr_en = 1'b0;

        line_wdata = wdata_r;

        case (state)

            // ----------------------------------------------------
            // Write Back Dirty Cache Block
            // ----------------------------------------------------

            WRITE_BACK: begin

                mem_req = 1'b1;
                mem_we = 1'b1;

                mem_addr = wb_addr + (burst_cnt << 2);

                mem_wdata =
                    block_rdata[burst_cnt*DATA_WIDTH +: DATA_WIDTH];

            end

            // ----------------------------------------------------
            // Allocate New Cache Block
            // ----------------------------------------------------

            ALLOCATE: begin

                mem_req = 1'b1;
                mem_we = 1'b0;

                mem_addr = block_base_addr + (burst_cnt << 2);

                if (mem_ready && burst_last) begin

                    block_wr_en = 1'b1;

                    tag_wr_en = 1'b1;

                    valid_wr_en = 1'b1;

                    dirty_wr_en = 1'b1;

                    dirty_wr_val = 1'b0;

                end

            end

            // ----------------------------------------------------
            // Update Cache Word
            // ----------------------------------------------------

            UPDATE: begin

                if (we_r) begin

                    word_wr_en = 1'b1;

                    dirty_wr_en = 1'b1;

                    dirty_wr_val = 1'b1;

                end

            end

        endcase

    end

    // ============================================================
    // CPU Read Data and Ready Signal
    // ============================================================

    assign cpu_rdata = line_rdata;

    assign cpu_ready = (state == DONE);

    // ============================================================
    // 4. Sequential Datapath Logic
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            addr_r <= {ADDR_WIDTH{1'b0}};

            wdata_r <= {DATA_WIDTH{1'b0}};

            we_r <= 1'b0;

            burst_cnt <= 2'd0;

            fetch_buf <= {(DATA_WIDTH*3){1'b0}};

            cpu_hit <= 1'b0;

        end

        else begin

            case (state)

                // ------------------------------------------------
                // Capture CPU Request
                // ------------------------------------------------

                IDLE: begin

                    if (cpu_req) begin

                        addr_r <= cpu_addr;

                        wdata_r <= cpu_wdata;

                        we_r <= cpu_we;

                    end

                end

                // ------------------------------------------------
                // Compare Tag
                // ------------------------------------------------

                COMPARE: begin

                    cpu_hit <= hit;

                end

                // ------------------------------------------------
                // Initialize Burst Counter
                // ------------------------------------------------

                WB_CHECK: begin

                    burst_cnt <= 2'd0;

                end

                // ------------------------------------------------
                // Write Back Burst Transfer
                // ------------------------------------------------

                WRITE_BACK: begin

                    if (mem_ready)

                        burst_cnt <= burst_last ?
                                     2'd0 : burst_cnt + 2'd1;

                end

                // ------------------------------------------------
                // Allocate Burst Transfer
                // ------------------------------------------------

                ALLOCATE: begin

                    if (mem_ready) begin

                        if (!burst_last)

                            fetch_buf[burst_cnt*DATA_WIDTH +: DATA_WIDTH]
                                <= mem_rdata;

                        burst_cnt <= burst_last ?
                                     2'd0 : burst_cnt + 2'd1;

                    end

                end

            endcase

        end

    end

endmodule
