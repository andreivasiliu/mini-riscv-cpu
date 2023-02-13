// UART (Universal Asynchronous Receiver Transmitter), aka serial interface

module uart_tx #(
    parameter BAUD_RATE = 115200,
    parameter CLOCK_SPEED = 100_000_000
  ) (
    input clk,
    input rst,
    input [7:0] tx_data,
    input tx_enable,
    output reg tx_done,
    output reg serial_out
  );

  parameter TICKS_PER_BIT = CLOCK_SPEED / BAUD_RATE;

  wire serial_clock;
  divide_by_n #(TICKS_PER_BIT) clock_divider (.clk, .rst, .out(serial_clock));

  reg [1:0] state;
  reg tx_active;
  reg [2:0] data_bits_sent;

  always @(posedge clk) begin
    if (tx_enable) begin
      tx_active <= 1;
    end else if (!tx_enable && state == 3) begin
      tx_active <= 0;
    end
  end

  always @(posedge serial_clock) begin
    case (state)
      // Idle
      0: begin
        data_bits_sent <= 0;
        if (tx_active) begin
          state <= 1;
          // Send start bit (low = active)
          serial_out <= 0;
          tx_done <= 0;
        end else begin
          state <= 0;
          // Keep idling (high = inactive)
          serial_out <= 1;
          tx_done <= 1;
        end
      end
      1: begin
        // Send data bits
        serial_out <= tx_data[data_bits_sent];
        data_bits_sent <= data_bits_sent + 1;
        if (data_bits_sent == 7) begin
          state <= 2;
        end
      end
      2: begin
        // Send stop bit
        serial_out <= 1;
        state <= 3;
      end
      3: begin
        // Wait until the requester finishes requesting this byte
        if (!tx_enable) begin
          state <= 0;
        end
      end
    endcase
  end
endmodule