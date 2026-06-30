// ==========================================
// Instruction Memory M9K
// ==========================================

module Instr_Memory_Core (

	input clk,
	
	input we,
	input [9:0] addr,
	input [31:0] wr_data,
	
	output [31:0] rd_data
);

	// Bank 0 (addr[9] == 0)
	wire cen0 = addr[9]; // Active low
	wire [7:0] q0_0, q0_1, q0_2, q0_3;

	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s0 (
		.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[7:0]), .Q(q0_0)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s1 (
		.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[15:8]), .Q(q0_1)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s2 (
		.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[23:16]), .Q(q0_2)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s3 (
		.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[31:24]), .Q(q0_3)
	);

	// Bank 1 (addr[9] == 1)
	wire cen1 = ~addr[9]; // Active low
	wire [7:0] q1_0, q1_1, q1_2, q1_3;

	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s0 (
		.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[7:0]), .Q(q1_0)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s1 (
		.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[15:8]), .Q(q1_1)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s2 (
		.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[23:16]), .Q(q1_2)
	);
	gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s3 (
		.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr[8:0]), .D(wr_data[31:24]), .Q(q1_3)
	);

	reg bank_sel_reg;
	always @(posedge clk) begin
		bank_sel_reg <= addr[9];
	end

	wire [31:0] q0 = {q0_3, q0_2, q0_1, q0_0};
	wire [31:0] q1 = {q1_3, q1_2, q1_1, q1_0};
	assign rd_data = bank_sel_reg ? q1 : q0;

endmodule