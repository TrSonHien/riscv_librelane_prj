// SPDX-FileCopyrightText: © 2025 XXX Authors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif
    
    input  wire clk,       // clock
    input  wire rst_n,     // reset (active low)
    
    input  wire [NUM_INPUT_PADS-1:0] input_in,   // Input value
    output wire [NUM_INPUT_PADS-1:0] input_pu,   // Pull-up
    output wire [NUM_INPUT_PADS-1:0] input_pd,   // Pull-down
 
    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,   // Input value
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,  // Output value
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,   // Output enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,   // Input type (0=CMOS Buffer, 1=Schmitt Trigger)
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,   // Slew rate (0=fast, 1=slow)
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,   // Input enable
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,   // Pull-up
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,   // Pull-down

    inout  wire [NUM_ANALOG_PADS-1:0] analog  // Analog
);

    // Disable pull-up and pull-down for input pads
    assign input_pu = '0;
    assign input_pd = '0;

    // Configure bidir pads
    assign bidir_cs = '0; // CMOS buffer
    assign bidir_sl = '0; // fast slew rate
    assign bidir_pu = '0; // no pull-up
    assign bidir_pd = '0; // no pull-down
    
    // Input enable should be high for inputs, low for outputs
    assign bidir_ie = ~bidir_oe;

    // Signal mappings:
    // Inputs (from pads):
    // input_in[3:0] -> SW[3:0]
    // bidir_in[0] -> GPIO_0 (UART_RX)
    // bidir_in[6:1] -> SW[9:4]
    
    wire [9:0] sw_sig;
    assign sw_sig[3:0] = input_in[3:0];
    assign sw_sig[9:4] = bidir_in[6:1];

    wire uart_rx_sig;
    assign uart_rx_sig = bidir_in[0];

    // Outputs (to pads):
    // bidir_out[7] -> GPIO_1 (UART_TX)
    // bidir_out[17:8] -> LEDR[9:0]
    // bidir_out[24:18] -> HEX0[6:0]
    // bidir_out[31:25] -> HEX1[6:0]
    // bidir_out[38:32] -> HEX2[6:0]
    
    wire uart_tx_sig;
    wire [9:0] ledr_sig;
    wire [6:0] hex0_sig, hex1_sig, hex2_sig;

    // Unused HEX ports
    wire [6:0] hex3_sig, hex4_sig, hex5_sig;

    // Map outputs to bidir output vector
    assign bidir_out[0]     = 1'b0;      // UART_RX is input
    assign bidir_out[6:1]   = 6'b0;      // SW[9:4] are inputs
    assign bidir_out[7]     = uart_tx_sig;
    assign bidir_out[17:8]  = ledr_sig;
    assign bidir_out[24:18] = hex0_sig;
    assign bidir_out[31:25] = hex1_sig;
    assign bidir_out[38:32] = hex2_sig;
    
    // Remaining bidir pads are unused outputs / inputs (tied to 0)
    assign bidir_out[NUM_BIDIR_PADS-1:39] = '0;

    // Output Enables:
    // 0 = Input, 1 = Output
    assign bidir_oe[0]     = 1'b0; // UART_RX
    assign bidir_oe[6:1]   = 6'b0; // SW[9:4]
    assign bidir_oe[7]     = 1'b1; // UART_TX
    assign bidir_oe[17:8]  = 10'h3FF; // LEDR
    assign bidir_oe[24:18] = 7'h7F;  // HEX0
    assign bidir_oe[31:25] = 7'h7F;  // HEX1
    assign bidir_oe[38:32] = 7'h7F;  // HEX2
    assign bidir_oe[NUM_BIDIR_PADS-1:39] = '0;

    // Instantiate the CPU Core subsystem
    CORE core_inst (
        .clk     (clk),
        .reset   (rst_n), // CORE reset is active-low
        .SW      (sw_sig),
        .GPIO_0  (uart_rx_sig),
        .LEDR    (ledr_sig),
        .HEX0    (hex0_sig),
        .HEX1    (hex1_sig),
        .HEX2    (hex2_sig),
        .HEX3    (hex3_sig),
        .HEX4    (hex4_sig),
        .HEX5    (hex5_sig),
        .GPIO_1  (uart_tx_sig),
        
        // VGA ports unconnected since VGA is disabled
        .VGA_HS  (),
        .VGA_VS  (),
        .VGA_R   (),
        .VGA_G   (),
        .VGA_B   ()
    );

endmodule

`default_nettype wire
