// Used to divide a clock into a slower clock.
module divide_by_n #(
    parameter N = 8,
    parameter BITS = $clog2(N)
) (
    input clk,
    input rst,
    output reg out
  );

  reg [BITS-1:0] counter;

  always @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      out <= 0;
    end else if (counter == N) begin
      counter <= 0;
      out <= 1;
    end else begin
      counter <= counter + 1;
      out <= 0;
    end
  end
endmodule
