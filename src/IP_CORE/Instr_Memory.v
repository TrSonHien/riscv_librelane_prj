// =======================================
// Module Instr_Memory
// + Bộ nhớ lưu firmware
// =======================================

module Instr_Memory #(
    parameter USE_SRAM = 0 // 0 = Synthesized logic gate ROM, 1 = SRAM macros
)(
	input clk,
	
	// CPU interface
	input [31:0] addr,					// Địa chỉ CPU muốn đọc instruction trong Memory
	output [31:0] instruction,
	
	// Bootloader interface
	input boot_mode,
	input we_boot,
	input [31:0] addr_boot,
	input [31:0] data_boot
);

	wire [9:0] addr_sel = boot_mode ? addr_boot[11:2] : addr[11:2];
	wire we = boot_mode && we_boot;

	generate
		if (USE_SRAM) begin : gen_sram
			// Bank 0 (addr_sel[9] == 0)
			wire cen0 = addr_sel[9]; // Active low: 0 when addr_sel[9] == 0
			wire [7:0] q0_0, q0_1, q0_2, q0_3;

			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s0 (
				.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[7:0]), .Q(q0_0)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s1 (
				.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[15:8]), .Q(q0_1)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s2 (
				.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[23:16]), .Q(q0_2)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0_s3 (
				.CLK(clk), .CEN(cen0), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[31:24]), .Q(q0_3)
			);

			// Bank 1 (addr_sel[9] == 1)
			wire cen1 = ~addr_sel[9]; // Active low: 0 when addr_sel[9] == 1
			wire [7:0] q1_0, q1_1, q1_2, q1_3;

			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s0 (
				.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[7:0]), .Q(q1_0)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s1 (
				.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[15:8]), .Q(q1_1)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s2 (
				.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[23:16]), .Q(q1_2)
			);
			gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1_s3 (
				.CLK(clk), .CEN(cen1), .GWEN(~we), .WEN(8'b0), .A(addr_sel[8:0]), .D(data_boot[31:24]), .Q(q1_3)
			);

			reg bank_sel_reg;
			always @(posedge clk) begin
				bank_sel_reg <= addr_sel[9];
			end

			wire [31:0] q0 = {q0_3, q0_2, q0_1, q0_0};
			wire [31:0] q1 = {q1_3, q1_2, q1_1, q1_0};
			assign instruction = bank_sel_reg ? q1 : q0;
		end else begin : gen_behavioral
			// Behavioral synthesizable ROM (logic gates)
			reg [31:0] rom_data [0:1023];
			reg [31:0] instruction_reg;

			initial begin
				$readmemh("firmware.hex", rom_data);
			end

			always @(posedge clk) begin
				instruction_reg <= rom_data[addr_sel];
			end

			assign instruction = instruction_reg;
		end
	endgenerate

endmodule