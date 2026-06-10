`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 14:30:21
// Design Name: 
// Module Name: axi_lite_slave_regs
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

module axi_lite_slave#(
    parameter ADDR_WIDTH        = 8,
    parameter DATA_WIDTH        = 32,
    parameter FIFO_LEVEL_WIDTH  = 5
    )(
    input clk,
    input resetn,
    
    // Write address channel signals
    input [ADDR_WIDTH-1:0]      S_AXI_AWADDR,
    input                       S_AXI_AWVALID,
    output reg                  S_AXI_AWREADY,
  
    // Write data channel signals
    input [DATA_WIDTH-1:0]      S_AXI_WDATA,
    input [(DATA_WIDTH/8)-1:0]  S_AXI_WSTRB,
    input                       S_AXI_WVALID,
    output reg                  S_AXI_WREADY,     
    
    // Response channel signals
    input                       S_AXI_BREADY,
    output reg [1:0]            S_AXI_BRESP,
    output reg                  S_AXI_BVALID,   
    
    // Read address channel signals
    input [ADDR_WIDTH-1:0]      S_AXI_ARADDR,
    
    // Read data channel signals
    input                       S_AXI_RREADY,
    output reg [1:0]            S_AXI_RRESP,
    output reg [DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg                  S_AXI_RVALID,
    
    input                       S_AXI_ARVALID,
    output reg                  S_AXI_ARREADY
    );
    
    
    
    // AWADDR function (which signal to change)
    localparam REG_CONTROL      = 8'h00;
    localparam REG_STATUS       = 8'h04;
    localparam REG_DATA_IN      = 8'h08;
    localparam REG_DATA_OUT     = 8'h0C;
    localparam REG_FIFO_LEVEL   = 8'h10;
    localparam REG_ERROR_STATUS = 8'h14;
    
   
    // Response signals 
    localparam RESP_OKAY    = 2'b00;
    localparam RESP_SLV_ERR = 2'b10;
    localparam RESP_DEC_ERR = 2'b11;
  
    
    //
    // Internal Registers 
    // 
    reg [ADDR_WIDTH-1:0]     awaddr_reg;
    reg                      awaddr_valid;  
    reg [DATA_WIDTH-1:0]     wdata_reg;
    reg [(DATA_WIDTH/8)-1:0] wstrb_reg;
    reg                      wdata_valid;
    
    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg                  araddr_valid;
    
    
    // Tells when read and write done
    reg write_done;
    reg read_done;
    
    // Control clear pulse 
    reg clear_error;
    
    // Error bits as seprate registers
    reg err_overflow;
    reg err_underflow;
    reg err_invalid_write;
    reg err_invalid_read;
    reg err_wstrb;
    
    // error status register
    wire [31:0] error_status;
    
    assign error_status = {27'd0,
                           err_wstrb,
                           err_invalid_read,
                           err_invalid_write,
                           err_underflow,
                           err_overflow
                           }; 
      
    
    // FIFO register
    reg                         fifo_wr_en;
    reg                         fifo_rd_en;
    reg [DATA_WIDTH-1:0]        fifo_din;
    
    wire [DATA_WIDTH-1:0]       fifo_dout;
    wire                        fifo_full;
    wire                        fifo_empty;
    wire [FIFO_LEVEL_WIDTH-1:0] fifo_level;
    wire                        fifo_overflow;
    wire                        fifo_underflow;
    
    // FIFO Instantiation
    sync_fifo FIFO (
        .clk      (clk),
        .reset_n  (resetn),
        .wr_en    (fifo_wr_en),
        .rd_en    (fifo_rd_en),
        .din      (fifo_din),
        .dout     (fifo_dout),
        .full     (fifo_full),
        .empty    (fifo_empty),
        .level    (fifo_level),
        .overflow (fifo_overflow),
        .underflow(fifo_underflow)
    );
    
    // FIFO status
    wire [31:0] fifo_status;
    wire any_error;

    // OR of all the bits of the error_status
    assign any_error = |(error_status);   
      
    assign fifo_status = {27'b0,
                          any_error,
                          err_underflow,
                          err_overflow,
                          fifo_empty,
                          fifo_full};
    
        
    // Write Address channel
    always @(posedge clk or negedge resetn) begin   
        if (!resetn) begin
            S_AXI_AWREADY <= 0;
            awaddr_reg    <= 0;
            awaddr_valid   <= 0;
        end
        else begin 
            if (!awaddr_valid) begin
                S_AXI_AWREADY <= 1;
                
                if (S_AXI_AWVALID & S_AXI_AWREADY) begin  
                    S_AXI_AWREADY <= 0;
                    awaddr_valid  <= 1;
                    awaddr_reg    <= S_AXI_AWADDR;
                end 
            end
            else begin
                S_AXI_AWREADY <= 0;   
            end
            
            if (write_done) begin
                awaddr_valid <= 0;
            end
        end
    end
    
    
    // Write data channel
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            S_AXI_WREADY  <= 0;
            wdata_valid   <= 0;
            wdata_reg     <= 0;
            wstrb_reg     <= 0;
        end
        else begin
              if (write_done) begin
                wdata_valid <= 0;
              end
              
              if (!wdata_valid) begin
                S_AXI_WREADY <= 1;
                  
                if (S_AXI_WVALID == 1 && S_AXI_WREADY) begin
                    S_AXI_WREADY <= 0;
                    wdata_reg    <= S_AXI_WDATA;
                    wstrb_reg    <= S_AXI_WSTRB;
                    wdata_valid  <= 1;
                end
              end      
              else begin
                S_AXI_WREADY <= 0;
              end
        end
    end
    
    
    // Write Response Channel && Execution block
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            S_AXI_BVALID      <= 1'b0;
            S_AXI_BRESP       <= RESP_OKAY;
            write_done        <= 0;
            clear_error       <= 0;
            
            fifo_wr_en        <= 0;
            fifo_din          <= 0;
            
            err_invalid_write <= 0;
            err_overflow      <= 0;
            err_wstrb         <= 0;
        end
        else begin
        
            if (clear_error) begin
                err_invalid_write <= 0;
                err_overflow      <= 0;
                err_wstrb         <= 0;
            end
        
        
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 0;
                write_done   <= 0;
            end    
            else if (awaddr_valid && wdata_valid && !S_AXI_BVALID) begin
                write_done   <= 1;
                S_AXI_BVALID <= 1;
                
                case(awaddr_reg) 
                    REG_CONTROL : begin
                        if (wdata_reg[1] == 1) begin
                            clear_error       <= 1;  
                            err_invalid_write <= 0;
                            err_overflow      <= 0;
                            err_wstrb         <= 0;
                        end
                        S_AXI_BRESP <= RESP_OKAY;
                    end
                    
                    REG_DATA_IN : begin
                        if (wstrb_reg != {(DATA_WIDTH/8){1'b1}}) begin
                            S_AXI_BRESP <= RESP_SLV_ERR;
                            err_wstrb   <= 1;
                        end
                        else if (fifo_full) begin
                            err_overflow <= 1'b1;
                            S_AXI_BRESP  <= RESP_SLV_ERR;
                        end
                        else begin
                            fifo_wr_en  <= 1;
                            fifo_din    <= wdata_reg;
                            S_AXI_BRESP <= RESP_OKAY;
                        end
                    end
                    
                    default : begin
                        S_AXI_BRESP       <= RESP_DEC_ERR;
                        err_invalid_write <= 1;
                    end
                endcase
            end 
            else begin
                write_done  <= 0;
                fifo_wr_en  <= 0;
                clear_error <= 0;
            end
            
        end
    end
    
    
    // READ ADDRESS CHANNEL
     always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            S_AXI_ARREADY <= 0;
            araddr_reg    <= 0;
            araddr_valid  <= 0;
        end
        else begin
        
            if (!araddr_valid) begin
                S_AXI_ARREADY <= 1;
                
                if (S_AXI_ARVALID & S_AXI_ARREADY) begin
                    S_AXI_ARREADY <= 0;
                    araddr_valid  <= 1;
                    araddr_reg    <= S_AXI_ARADDR;
                end
            end 
            else begin
                S_AXI_ARREADY <= 0;
            end
            
            if (read_done) begin
                araddr_valid <= 0;
            end
            
        end    
     end
    
    
    
    // breaking read into FSM as read will take 1 clock cycle to 
    // get S_AXI_RDATA after the insertion of the read enable signal
    localparam RD_IDLE      = 2'd0;
    localparam RD_FIFO_READ = 2'd1;
    localparam RD_FIFO_WAIT = 2'd2;
    localparam RD_RESP      = 2'd3;
    
    reg [1:0] read_state;
    
    
    
    // READ DATA CHANNEL 
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            S_AXI_RDATA      <= {DATA_WIDTH{1'b0}};
            S_AXI_RVALID     <= 1'b0;
            S_AXI_RRESP      <= RESP_OKAY;
    
            fifo_rd_en       <= 1'b0;
            read_done        <= 1'b0;
            err_underflow    <= 1'b0;
            err_invalid_read <= 1'b0;
    
            read_state       <= RD_IDLE;
        end
        else begin
            fifo_rd_en <= 1'b0;
            read_done  <= 1'b0;
    
            if (clear_error) begin
                err_underflow    <= 1'b0;
                err_invalid_read <= 1'b0;
            end
    
            case (read_state)
    
                RD_IDLE: begin
                    if (araddr_valid && !S_AXI_RVALID) begin
                        case (araddr_reg)
    
                            REG_STATUS: begin
                                S_AXI_RDATA  <= fifo_status;
                                S_AXI_RRESP  <= RESP_OKAY;
                                S_AXI_RVALID <= 1'b1;
                                read_state   <= RD_RESP;
                            end
    
                            REG_DATA_OUT: begin
                                if (fifo_empty) begin
                                    err_underflow <= 1'b1;
                                    S_AXI_RDATA   <= {DATA_WIDTH{1'b0}};
                                    S_AXI_RRESP   <= RESP_SLV_ERR;
                                    S_AXI_RVALID  <= 1'b1;
                                    read_state    <= RD_RESP;
                                end
                                else begin
                                    fifo_rd_en <= 1'b1;
                                    read_state <= RD_FIFO_READ;
                                end
                            end
    
                            REG_FIFO_LEVEL: begin
                                S_AXI_RDATA  <= {{(DATA_WIDTH-FIFO_LEVEL_WIDTH){1'b0}}, fifo_level};
                                S_AXI_RRESP  <= RESP_OKAY;
                                S_AXI_RVALID <= 1'b1;
                                read_state   <= RD_RESP;
                            end
    
                            REG_ERROR_STATUS: begin
                                S_AXI_RDATA  <= error_status;
                                S_AXI_RRESP  <= RESP_OKAY;
                                S_AXI_RVALID <= 1'b1;
                                read_state   <= RD_RESP;
                            end
    
                            default: begin
                                err_invalid_read <= 1'b1;
                                S_AXI_RDATA      <= {DATA_WIDTH{1'b0}};
                                S_AXI_RRESP      <= RESP_DEC_ERR;
                                S_AXI_RVALID     <= 1'b1;
                                read_state       <= RD_RESP;
                            end
    
                        endcase
                    end
                end
                
                RD_FIFO_READ: begin
                    read_state <= RD_FIFO_WAIT;
                end
    
                RD_FIFO_WAIT: begin
                    S_AXI_RDATA  <= fifo_dout;
                    S_AXI_RRESP  <= RESP_OKAY;
                    S_AXI_RVALID <= 1'b1;
                    read_state   <= RD_RESP;
                end
    
                RD_RESP: begin
                    if (S_AXI_RVALID && S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        read_done    <= 1'b1;
                        read_state   <= RD_IDLE;
                    end
                end
    
                default: begin
                    read_state <= RD_IDLE;
                end
    
            endcase
        end
    end
    
endmodule