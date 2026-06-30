// =====================================================
// Module Font_ROM
// + Bộ Font ASCII cho VGA
// + Kích thước font chữ 8x16 pixel
// -----------------------------------------------------
// + 640 / 8 = 80 cột
// + 480 / 16 = 30 hàng
// ==> Màn hình hiển thị được 30 hàng, 80 ký tự/hàng
// =====================================================

module Font_ROM (

    input clk_vga,              // Clock 25MHz
    input [11:0] addr,

    output reg [7:0] data
);

    wire cen0 = !(addr[11:9] == 3'd0);
    wire cen1 = !(addr[11:9] == 3'd1);
    wire cen2 = !(addr[11:9] == 3'd2);
    wire cen3 = !(addr[11:9] == 3'd3);
    wire cen4 = !(addr[11:9] == 3'd4);
    wire cen5 = !(addr[11:9] == 3'd5);
    wire cen6 = !(addr[11:9] == 3'd6);
    wire cen7 = !(addr[11:9] == 3'd7);

    wire [7:0] q0, q1, q2, q3, q4, q5, q6, q7;

    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b0 (
        .CLK(clk_vga), .CEN(cen0), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q0)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b1 (
        .CLK(clk_vga), .CEN(cen1), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q1)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b2 (
        .CLK(clk_vga), .CEN(cen2), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q2)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b3 (
        .CLK(clk_vga), .CEN(cen3), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q3)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b4 (
        .CLK(clk_vga), .CEN(cen4), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q4)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b5 (
        .CLK(clk_vga), .CEN(cen5), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q5)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b6 (
        .CLK(clk_vga), .CEN(cen6), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q6)
    );
    gf180mcu_fd_ip_sram__sram512x8m8wm1 sram_b7 (
        .CLK(clk_vga), .CEN(cen7), .GWEN(1'b1), .WEN(8'b0), .A(addr[8:0]), .D(8'b0), .Q(q7)
    );

    reg [2:0] bank_sel_reg;
    always @(posedge clk_vga) begin
        bank_sel_reg <= addr[11:9];
    end

    always @(*) begin
        case (bank_sel_reg)
            3'd0: data = q0;
            3'd1: data = q1;
            3'd2: data = q2;
            3'd3: data = q3;
            3'd4: data = q4;
            3'd5: data = q5;
            3'd6: data = q6;
            3'd7: data = q7;
            default: data = 8'b0;
        endcase
    end

    // Simulation Initialization Helper
    reg [7:0] temp_rom [0:4095];
    integer i;
    initial begin
        $readmemh("font8x16.hex", temp_rom);
        for (i = 0; i < 512; i = i + 1) begin
            sram_b0.mem[i] = temp_rom[0*512 + i];
            sram_b1.mem[i] = temp_rom[1*512 + i];
            sram_b2.mem[i] = temp_rom[2*512 + i];
            sram_b3.mem[i] = temp_rom[3*512 + i];
            sram_b4.mem[i] = temp_rom[4*512 + i];
            sram_b5.mem[i] = temp_rom[5*512 + i];
            sram_b6.mem[i] = temp_rom[6*512 + i];
            sram_b7.mem[i] = temp_rom[7*512 + i];
        end
    end

endmodule