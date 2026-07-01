// ====================================
// Module Forwarding_Unit
// ====================================

module Forwarding_Unit (

	input RegWriteE,
	input MemReadE,
	input RegWriteM,			// Insruction ở MEM có ghi vào Register không

	input [4:0] RD_E,
	input [4:0] RD_M,			// Thanh ghi đích của Instruction ở MEM

	input [4:0] RS1_D,			// Từ Decode stage
	input [4:0] RS2_D,			// Từ Decode stage

	// -----------------------
	// Output sang Decode stage, dang ky vao ID/EX
	// -----------------------
	output reg [1:0] ForwardA_D,
	output reg [1:0] ForwardB_D
);

	always @(*) begin

		// =============== DEFAULT ===============
		ForwardA_D = 2'b00;
		ForwardB_D = 2'b00;

		// =============== Forward A ===============
		if (RegWriteE && !MemReadE && (RD_E != 0) && (RD_E == RS1_D)) begin
			ForwardA_D = 2'b10;
		end
		else if (RegWriteM && (RD_M != 0) && (RD_M == RS1_D)) begin
			ForwardA_D = 2'b01;
		end

		// =============== Forward B ===============
		if (RegWriteE && !MemReadE && (RD_E != 0) && (RD_E == RS2_D)) begin
			ForwardB_D = 2'b10;
		end
		else if (RegWriteM && (RD_M != 0) && (RD_M == RS2_D)) begin
			ForwardB_D = 2'b01;
		end

	end

endmodule
