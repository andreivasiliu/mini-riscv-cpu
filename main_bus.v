// A bus that routes memory requests to a peripheral based on the first 16 bits
// of the address.

module main_bus (
  input clk,
  input cpu_clk,
  input rst,
  input [31:0] bus_write_address,
  input [31:0] bus_write_data,
  input [31:0] bus_read_address,
  output reg [31:0] bus_read_data,
  output wire serial_out,
  output reg [31:0] display_out
);
  wire [15:0] read_peripheral = bus_read_address[31:16];
  wire [15:0] read_word_address = bus_read_address[15:2];

  wire [15:0] write_peripheral = bus_write_address[31:16];
  wire [15:0] write_word_address = bus_write_address[15:2];

  // 4KB of RAM, all of it as L1 cache.
  reg [31:0] memory [0:1023];

  // A serial transmitter
  uart_tx #(115200) uart_tx (
    .clk, .rst, .serial_out, .tx_enable, .tx_data, .tx_done
  );

  reg tx_enable;
  reg [7:0] tx_data;
  wire tx_done;

  initial begin
    $readmemh("program.hex", memory);
  end

  always @(posedge cpu_clk) begin
    tx_enable <= 0;

    case (read_peripheral[1:0])
      // 0x10000 - Memory
      1: bus_read_data <= memory[read_word_address];
      // 0x20000 - UART0
      2: case (read_word_address)
        16'h00 >> 2: bus_read_data <= tx_data;
        16'h04 >> 2: bus_read_data <= tx_done;
      endcase
      // 0x30000 - 7-segment display
      3: bus_read_data <= display_out;
      default: bus_read_data <= 0;
    endcase

    case (write_peripheral[1:0])
      // Memory
      1: memory[write_word_address] <= bus_write_data;
      // UART0
      2: begin
        tx_data <= bus_write_data[7:0];
        tx_enable <= 1;
      end
      // 7-segment display
      3: display_out <= bus_write_data;
      default: begin end
    endcase
  end
endmodule