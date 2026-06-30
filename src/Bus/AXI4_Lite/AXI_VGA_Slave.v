// ============================================================================
// Module AXI_VGA_Slave (DUMMY BASE VERSION)
// ----------------------------------------------------------------------------
// AXI4-Lite Dummy VGA Slave (Disabled to save area and macros)
// ============================================================================

module AXI_VGA_Slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)
(
    input clk,
    input reset, // Active-LOW

    // WRITE ADDRESS CHANNEL
    input  [ADDR_WIDTH-1:0] s_axi_awaddr,
    input                   s_axi_awvalid,
    output                  s_axi_awready,

    // WRITE DATA CHANNEL
    input  [DATA_WIDTH-1:0]     s_axi_wdata,
    input  [DATA_WIDTH/8-1:0]   s_axi_wstrb,     
    input                       s_axi_wvalid,
    output                  s_axi_wready,

    // WRITE RESPONSE CHANNEL
    output reg [1:0]            s_axi_bresp,
    output reg                  s_axi_bvalid,
    input                       s_axi_bready,

    // READ ADDRESS CHANNEL
    input  [ADDR_WIDTH-1:0]     s_axi_araddr,
    input                       s_axi_arvalid,
    output                  s_axi_arready,

    // READ DATA CHANNEL
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0]            s_axi_rresp,
    output reg                  s_axi_rvalid,
    input                       s_axi_rready,

    // VGA OUTPUT
    output VGA_HS,
    output VGA_VS,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B
);

    // Tie off VGA hardware ports
    assign VGA_HS = 1'b0;
    assign VGA_VS = 1'b0;
    assign VGA_R  = 4'b0;
    assign VGA_G  = 4'b0;
    assign VGA_B  = 4'b0;

    // AXI-Lite handshakes are immediate
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;

    // Write response state machine
    always @(posedge clk) begin
        if (!reset) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b10; // SLVERR
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Read response state machine
    always @(posedge clk) begin
        if (!reset) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 32'b0;
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b10; // SLVERR
                s_axi_rdata  <= 32'b0;
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule