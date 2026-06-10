`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4
)(
    input                       clk,
    input                       reset_n,

    input                       wr_en,
    input                       rd_en,
    input  [DATA_WIDTH-1:0]     din,
    output reg [DATA_WIDTH-1:0] dout,

    output                      full,
    output                      empty,
    output reg [ADDR_WIDTH:0]   level,

    output reg                  overflow,
    output reg                  underflow
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign full  = (level == DEPTH);
    assign empty = (level == 0);

    integer i;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_ptr    <= {ADDR_WIDTH{1'b0}};
            rd_ptr    <= {ADDR_WIDTH{1'b0}};
            level     <= {(ADDR_WIDTH+1){1'b0}};
            dout      <= {DATA_WIDTH{1'b0}};
            overflow  <= 1'b0;
            underflow <= 1'b0;

            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            overflow  <= 1'b0;
            underflow <= 1'b0;

            case ({wr_en && !full, rd_en && !empty})

                2'b10: begin
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    level       <= level + 1'b1;
                end

                2'b01: begin
                    dout   <= mem[rd_ptr];
                    rd_ptr <= rd_ptr + 1'b1;
                    level  <= level - 1'b1;
                end

                2'b11: begin
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;

                    dout        <= mem[rd_ptr];
                    rd_ptr      <= rd_ptr + 1'b1;

                    level       <= level;
                end

                default: begin
                    level <= level;
                end

            endcase

            if (wr_en && full) begin
                overflow <= 1'b1;
            end

            if (rd_en && empty) begin
                underflow <= 1'b1;
            end
        end
    end

endmodule