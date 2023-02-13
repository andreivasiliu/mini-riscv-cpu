module main (
    input clk,
    input rst,
    output [7:0] led,
    input usb_rx,
    output usb_tx,
    output [23:0] io_led,
    output [7:0] io_seg,
    output [3:0] io_sel,
    input [4:0] io_button,
    input [23:0] io_dip
  );

  wire slow_clk;

  // divide_by_n #(5_000_000) sc (.clk, .rst, .out(slow_clk));

  variable_clock vc (
    .clk, .rst, .var_clk(slow_clk),
    .speed({io_button[0], io_button[1], io_button[2]})
  );

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
    .display_out
  );

  riscv_core cpu (
    .cpu_clk(slow_clk),
    .rst,
    .bus_read_address,
    .bus_read_data,
    .bus_write_address,
    .bus_write_data,
    .leds24(io_led),
    .leds8(led)
  );

  four_digit_multiplexer fdm (
    .clk,
    .four_digits(display_out),
    .digit(io_seg),
    .digit_selector(io_sel)
  );
endmodule

// A clock with 3 speeds, which transitions slowly from one speed to another
// for a cool speed-up effect.
module variable_clock (
    input clk,
    input rst,
    input [2:0] speed,
    output reg var_clk
  );

  reg [31:0] var_clk_counter;
  reg [31:0] target_limit;
  reg [31:0] current_limit;
  reg [24:0] target_counter;

  initial begin
    current_limit <= 4_194_304;
    target_limit <= 4_194_304;
  end

  always @(posedge clk) begin
    var_clk_counter <= var_clk_counter + 1;
    target_counter <= target_counter + 1;

    if (speed[0]) begin
      target_limit <= 4_194_304;  // 2 ** 22
    end else if (speed[1]) begin
      target_limit <= 32_768;  // 2 ** 15
    end else if (speed[2]) begin
      target_limit <= 16;  // 2 ** 4
    end

    if (target_counter == 0) begin
      if (current_limit > target_limit) begin
        current_limit <= current_limit >> 1;
      end else if (current_limit < target_limit) begin
        current_limit <= current_limit << 1;
      end
    end

    if (var_clk_counter > current_limit) begin
      var_clk_counter <= 0;
      var_clk <= 1;
    end else begin
      var_clk <= 0;
    end

    if (rst) begin
      var_clk_counter <= 0;
      target_counter <= 0;
      target_limit <= 4_194_304;
      current_limit <= 4_194_304;
    end
  end
endmodule