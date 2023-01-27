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

  wire [23:0] out24;
  wire [7:0] out8;
  wire slow_clk;

  divide_by_n #(5_000_000) _sc (.clk, .rst, .out(slow_clk));

  riscv_core cpu (
    .clk(slow_clk),
    .rst,
    .out24,
    .out8,
  );

  always @* begin
    io_seg <= out8;
    io_sel <= 4'b0001;
    io_led <= out24;
    led <= io_button;
    usb_tx <= usb_rx;
    // io_led[23:16] <= io_dip[23:16];
  end
endmodule
