module main (
    input clk,
    input rst,
    output reg [7:0] led,
    input usb_rx,
    output reg usb_tx,
    output reg [23:0] io_led,
    output reg [7:0] io_seg,
    output reg [3:0] io_sel,
    input [4:0] io_button,
    input [23:0] io_dip,
  );

  wire [23:0] out;

  riscv_core cpu (
    .clk,
    .rst,
    .out,
  );

  always @* begin
    io_seg <= 0;
    io_sel <= 0;
    io_led <= out;
    led <= io_button;
    usb_tx <= usb_rx;
    // io_led[23:16] <= io_dip[23:16];
  end
endmodule
