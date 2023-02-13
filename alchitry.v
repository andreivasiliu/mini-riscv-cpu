// Top circuit for the Alchitry Cu + Alchitry Io boards.
// This forwards signal to a `main` module, but fixes some of the Alchitry
// boards' quirks/bugs first.
module alchitry_top (
    input clk,
    input rst_n,
    output [7:0] led,
    input usb_rx,
    output usb_tx,
    output [23:0] io_led,
    output [7:0] io_seg_n,
    output [3:0] io_sel_n,
    inout [4:0] io_button_bugged,
    inout [23:0] io_dip
  );

  wire rst;

  assign rst = ~rst_n;

  wire [4:0] io_button_fixed;
  pull_down button_pull_down (
    .clk(clk),
    .in(io_button_bugged),
    .out(io_button_fixed)
  );

  wire [3:0] io_sel;
  wire [7:0] io_seg;

  main main (
    .clk(clk),
    .rst(rst),
    .led(led),
    .usb_rx(usb_rx),
    .usb_tx(usb_tx),
    .io_led(io_led),
    .io_seg(io_seg),
    .io_sel(io_sel),
    .io_button(io_button_fixed),
    .io_dip(io_dip)
  );

  assign io_sel_n = ~io_sel;
  assign io_seg_n = ~io_seg;
endmodule

// Copied from Alchitry Labs' example; this fixes the IO board's buttons by
// simulating a pull-down resistor.
// It looks ugly because it was auto-generated from Lucid code.
module pull_down (
    input clk,
    inout [4:0] in,
    output reg [4:0] out
  );
  
  localparam SIZE = 3'h5;
  reg [4:0] IO_in_enable;
  wire [4:0] IO_in_read;
  reg [4:0] IO_in_write;
  genvar GEN_in;
  for (GEN_in = 0; GEN_in < 5; GEN_in = GEN_in + 1) begin
    assign in[GEN_in] = IO_in_enable[GEN_in] ? IO_in_write[GEN_in] : 1'bz;
  end
  assign IO_in_read = in;
  
  
  reg [3:0] M_flip_d, M_flip_q = 1'h0;
  reg [4:0] M_saved_d, M_saved_q = 1'h0;
  
  always @* begin
    M_saved_d = M_saved_q;
    M_flip_d = M_flip_q;
    
    M_flip_d = M_flip_q + 1'h1;
    IO_in_write = 1'h0;
    IO_in_enable = {3'h5{M_flip_q == 1'h0}};
    if (M_flip_q > 2'h2) begin
      M_saved_d = IO_in_read;
    end
    out = M_saved_q;
  end
  
  always @(posedge clk) begin
    M_flip_q <= M_flip_d;
    M_saved_q <= M_saved_d;
  end
  
endmodule
