module main (
    input clk,
    input rst,
    output reg [7:0] led,
    input usb_rx,
    output reg usb_tx,
    output [23:0] io_led,
    output reg [7:0] io_seg,
    output reg [3:0] io_sel,
    input [4:0] io_button,
    input [23:0] io_dip,
  );

  wire slow_clk;

  divide_by_n #(5_000_000) _sc (.clk, .rst, .out(slow_clk));

  wire [31:0] bus_read_address, bus_read_data;
  wire [31:0] bus_write_address, bus_write_data;
  wire [31:0] display_out;

  main_bus bus (
    .clk,
    .cpu_clk(slow_clk),
    .rst,
    .bus_read_address,
    .bus_read_data,
    .bus_write_address,
    .bus_write_data,
    .serial_out(usb_tx),
    .display_out,
  );

  riscv_core cpu (
    .cpu_clk(slow_clk),
    .rst,
    .bus_read_address,
    .bus_read_data,
    .bus_write_address,
    .bus_write_data,
    .leds24(io_led),
    .leds8(led),
  );

  four_digit_multiplexer fdm (
    .clk,
    .four_digits(display_out),
    .digit(io_seg),
    .digit_selector(io_sel),
  );

  always @* begin
  end
endmodule
