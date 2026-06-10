`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.06.2026 13:52:30
// Design Name: 
// Module Name: axi_lite_master_tb
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


module axi_lite_master_tb();

localparam DATA_WIDTH        = 32;
localparam ADDR_WIDTH       = 8;
localparam FIFO_LEVEL_WIDTH = 5;
localparam FIFO_DEPTH       = 16;


// REGISTERS 
reg clk;
reg resetn;

//Write channel signals
reg [ADDR_WIDTH-1:0]      M_AXI_AWADDR;
reg                       M_AXI_AWVALID;
wire                      M_AXI_AWREADY;
reg [DATA_WIDTH-1:0]      M_AXI_WDATA;
reg [(DATA_WIDTH/8)-1:0]  M_AXI_WSTRB;
reg                       M_AXI_WVALID;
wire                      M_AXI_WREADY;     
reg                       M_AXI_BREADY;
wire [1:0]                M_AXI_BRESP;
wire                      M_AXI_BVALID;   
    
// Read channel signals
reg [ADDR_WIDTH-1:0]      M_AXI_ARADDR;
reg                       M_AXI_RREADY;
wire [1:0]                M_AXI_RRESP;
wire [DATA_WIDTH-1:0]     M_AXI_RDATA;
wire                      M_AXI_RVALID;   
reg                       M_AXI_ARVALID;
wire                      M_AXI_ARREADY;


// SLAVE INSTANTIATION
axi_lite_slave slave (
    .clk(clk),
    .resetn(resetn),
    
    .S_AXI_AWADDR  (M_AXI_AWADDR),
    .S_AXI_AWVALID (M_AXI_AWVALID),
    .S_AXI_AWREADY (M_AXI_AWREADY),
    .S_AXI_WDATA   (M_AXI_WDATA),
    .S_AXI_WSTRB   (M_AXI_WSTRB),
    .S_AXI_WVALID  (M_AXI_WVALID),
    .S_AXI_WREADY  (M_AXI_WREADY),
    .S_AXI_BREADY  (M_AXI_BREADY),
    .S_AXI_BRESP   (M_AXI_BRESP),
    .S_AXI_BVALID  (M_AXI_BVALID),
    
    .S_AXI_ARADDR  (M_AXI_ARADDR),
    .S_AXI_RREADY  (M_AXI_RREADY),
    .S_AXI_RRESP   (M_AXI_RRESP),
    .S_AXI_RDATA   (M_AXI_RDATA),
    .S_AXI_RVALID  (M_AXI_RVALID),
    .S_AXI_ARVALID (M_AXI_ARVALID),
    .S_AXI_ARREADY (M_AXI_ARREADY)   
);


// CLOCK GENERATION
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end


// WRITE/READ INFORMATION REGISTERS
reg [DATA_WIDTH-1:0] WRITE_DATA;
reg [ADDR_WIDTH-1:0] WRITE_ADDR;

reg [ADDR_WIDTH-1:0] READ_ADDR;
reg [DATA_WIDTH-1:0] READ_DATA_OUT;


// Write task
task write (input [DATA_WIDTH-1:0] WRITE_DATA,
            input [ADDR_WIDTH-1:0] WRITE_ADDR);
 begin
   
    @(negedge clk) begin   
        M_AXI_AWADDR   = WRITE_ADDR;
        M_AXI_AWVALID  = 1'b1;
           
        M_AXI_WDATA    = WRITE_DATA;
        M_AXI_WVALID   = 1;
        M_AXI_WSTRB    = 4'b1111;
        
        M_AXI_BREADY   = 1;
    end
    
    @(posedge clk);              // IT WILL KEEP AWVALID/WVALID HIGH FOR ONE FULL CLOCK CYCLE
   
    @(negedge clk);
    M_AXI_AWVALID = 0;
    M_AXI_WVALID  = 0;
    
    
    wait(M_AXI_BVALID == 1);
    @(posedge clk);              // allow BVALID && BREADY handshake inside slave
    @(negedge clk) begin
        M_AXI_BREADY = 0;
    end
    
 end   
endtask


// Read Task
task read (input  [ADDR_WIDTH-1:0] READ_ADDR    , 
           output [DATA_WIDTH-1:0] READ_DATA_OUT);
    begin
        
        @(negedge clk) begin
            M_AXI_ARADDR  = READ_ADDR;
            M_AXI_ARVALID = 1;
            M_AXI_RREADY  = 1;
        end
        
        wait (M_AXI_ARREADY == 1);
        @(negedge clk) begin
            M_AXI_ARVALID = 0;
        end
        
        wait (M_AXI_RVALID == 1);
        READ_DATA_OUT = M_AXI_RDATA;
        
        @(posedge clk);            // allow RVALID && RREADY handshake inside slave
        @(negedge clk) begin
            M_AXI_RREADY = 0;
        end
    end
endtask


initial begin
    
    // INTIALIZATION OF SIGNALS
    resetn = 0;
    
    
    M_AXI_AWADDR  = 0;
    M_AXI_AWVALID = 0;
    M_AXI_WDATA   = 0;
    M_AXI_WVALID  = 0;
    M_AXI_WSTRB   = 0;
    M_AXI_BREADY  = 0;
    
    M_AXI_ARADDR  = 0;
    M_AXI_ARVALID = 0;
    M_AXI_RREADY  = 0;

    
    repeat(5)@(posedge clk);
    resetn = 1;
    repeat(2)@(posedge clk);
    
    WRITE_DATA = 32'hA0C21113;
    WRITE_ADDR = 8'h08;         // DATA_IN register address
    
    // writing task
    write (WRITE_DATA,WRITE_ADDR);
    $display("WRITE OPERATION COMPLETED , BRESP = %b", M_AXI_BRESP);
    
    
    READ_ADDR = 8'h0C;          // DATA_OUT register address

    // READING TASK
    read (READ_ADDR,READ_DATA_OUT);
    $display("READ OPERATION COMPLETED , RDATA = %b", READ_DATA_OUT);
    
    #100;
    $finish;
    
end

endmodule
