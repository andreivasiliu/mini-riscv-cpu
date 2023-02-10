// The "display" is a 4-digit seven-segment display

module four_digit_multiplexer (
    input clk,
    input [31:0] four_digits,
    output reg[7:0] digit,
    output reg[3:0] digit_selector,
  );

  reg [1:0] counter;

  wire mux_clk;

  divide_by_n #(10_000) clk_divider (.clk, .rst(1'b0), .out(mux_clk));

  always @(posedge mux_clk) begin
    counter <= counter + 1;

    case (counter)
      0: begin
        digit_selector <= 4'b0001;
        digit <= four_digits[1*8-1:0*8];
      end
      1: begin
        digit_selector <= 4'b0010;
        digit <= four_digits[2*8-1:1*8];
      end
      2: begin
        digit_selector <= 4'b0100;
        digit <= four_digits[3*8-1:2*8];
      end
      3: begin
        digit_selector <= 4'b1000;
        digit <= four_digits[4*8-1:3*8];
      end
    endcase
  end
endmodule
