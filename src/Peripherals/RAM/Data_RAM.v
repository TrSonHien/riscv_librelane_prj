// ============================================================
// Module Data_RAM
// ============================================================

module Data_RAM (

	input clk,
	input [31:0] addr,
	input [31:0] write_data,

	input read_en,
	input write_en,
	
	output reg [31:0] read_data
);

	wire [9:0] addr_sel = addr[11:2];

	wire cen_global = ~(read_en | write_en);
	wire cen0 = cen_global | addr_sel[9];
	wire cen1 = cen_global | ~addr_sel[9];

	wire [7:0] q0_0, q0_1, q0_2, q0_3;
	wire [7:0] q1_0, q1_1, q1_2, q1_3;

	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s0 (
		.CLK(clk), .CEN(cen0), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[7:0]), .Q(q0_0)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s1 (
		.CLK(clk), .CEN(cen0), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[15:8]), .Q(q0_1)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s2 (
		.CLK(clk), .CEN(cen0), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[23:16]), .Q(q0_2)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s3 (
		.CLK(clk), .CEN(cen0), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[31:24]), .Q(q0_3)
	);

	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s0 (
		.CLK(clk), .CEN(cen1), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[7:0]), .Q(q1_0)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s1 (
		.CLK(clk), .CEN(cen1), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[15:8]), .Q(q1_1)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s2 (
		.CLK(clk), .CEN(cen1), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[23:16]), .Q(q1_2)
	);
	(* keep *) gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s3 (
		.CLK(clk), .CEN(cen1), .GWEN(~write_en), .WEN(8'b0), .A(addr_sel[8:0]), .D(write_data[31:24]), .Q(q1_3)
	);

	reg bank_sel_reg;
	always @(posedge clk) begin
		if (read_en) begin
			bank_sel_reg <= addr_sel[9];
		end
	end

	wire [31:0] q0 = {q0_3, q0_2, q0_1, q0_0};
	wire [31:0] q1 = {q1_3, q1_2, q1_1, q1_0};

	always @(*) begin
		read_data = bank_sel_reg ? q1 : q0;
	end

endmodule