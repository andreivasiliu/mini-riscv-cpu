module riscv_core(
    input cpu_clk,
    input rst,
    input [31:0] bus_read_data,
    output reg [31:0] bus_read_address,
    output reg [31:0] bus_write_data,
    output reg [31:0] bus_write_address,
    output [7:0] leds8,
    output [23:0] leds24,
  );

  // CPU internal state
  // reg [1:0] stage;  // 4-stage CPU
  reg [2:0] stage;  // 6?-stage CPU :(
  reg [31:0] instruction;  // The current instruction being executed
  reg [29:0] program_counter, jump_target, branch_target;  // Flow control
  reg branch_condition;  // If true, jump to branch_target
  reg exception;  // If true, the CPU didn't understand this instruction

  // TODO: moved to main_bus
  // reg [31:0] memory [0:1023];  // 4KB of RAM, all of it as L1 cache.
  reg [31:0] registers [0:31];  // x0 to x31 registers

  // Various interpretations of the instruction bits
  wire [6:0] opcode = instruction[6:0];
  wire [4:0] rd = instruction[11:7];  // Destination register
  // wire [4:0] rs1 = instruction[19:15];  // Argument 1
  // wire [4:0] rs2 = instruction[24:20];  // Argument 2
  reg [4:0] rs1, rs2;
  wire [6:0] funct7 = instruction[31:25];
  wire [2:0] funct3 = instruction[14:12];

  // Various immediate representations (constant numbers embedded into the instruction)
  // wire [11:0] imm12 = instruction[31:20];
  reg [11:0] imm12;
  wire signed [11:0] imm12_b = {
    instruction[31], instruction[7], instruction[30:25], instruction[11:8]
  };
  // TODO: Check operations on non :0 wires
  wire [31:12] imm20_u = instruction[31:12];
  wire signed [21:2] imm20_j = {
    instruction[31], instruction[19:12], instruction[20], instruction[30:21]
  };
  // wire signed [11:0] store_offset = {instruction[31:25], instruction[11:7]};
  // wire signed [11:0] load_offset = instruction[31:20];
  reg signed [11:0] store_offset;
  reg signed [11:0] load_offset;

  // Values of current registers being operated upon
  reg signed [31:0] rs1_value, rs2_value, rd_value;
  wire [31:0] rs1_value_unsigned = rs1_value;
  wire [31:0] rs2_value_unsigned = rs2_value;

  // Immediates sign-extended to 32-bits
  reg signed [31:0] imm12_value, store_word, load_word;
  reg [31:0] store_location, load_location;
  wire [31:0] imm12_value_unsigned = imm12_value;

  // Register+offset, used for both addi and as a jump target
  wire [31:0] rs1_plus_imm12 = rs1_value + imm12_value;

  assign leds24 = {exception, program_counter[6:0], bus_write_data[15:0]};
  assign leds8 = {bus_write_address[17:16], 3'b000, stage[2:0]};

  initial begin
    // The main bus serves memory contents starting with this address
    program_counter <= 32'h10000 >> 2;
  end

  always @(posedge cpu_clk) begin
    stage <= stage + 1;

    case (stage)
      // Stage 0 - reset state and read next instruction
      0: begin
        bus_read_address <= {program_counter, 2'b00};
        bus_write_address <= 0;
        registers[0] <= 32'b0;
        jump_target <= program_counter + 1;
        branch_condition <= 0;
        exception <= 0;
      end
      // Stage 0b - wait for instruction
      1: begin
        bus_read_address <= 0;
      end
      // Stage 1 - fetch registers and compute memory offsets
      2: begin
        instruction = bus_read_data;
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        rs2_value <= registers[rs2];
        imm12 = instruction[31:20];
        imm12_value <= {{20{imm12[11]}}, imm12};
        rs1_value = registers[rs1];
        store_offset = {instruction[31:25], instruction[11:7]};
        load_offset = instruction[31:20];
        load_location = rs1_value + load_offset;
        store_location = rs1_value + store_offset;
        case (opcode[6:2])
          5'b00000: bus_read_address <= {load_location[31:2], 2'b00};
          5'b01000: bus_read_address <= {store_location[31:2], 2'b00};
          default: bus_read_address <= 0;
        endcase
        bus_write_address <= 0;
      end
      // Stage 1b - wait for memory read
      3: begin
        bus_read_address <= 0;
      end
      // Stage 2 - compute result of operation
      4: begin
        bus_read_address <= 0;
        if (opcode[6:2] == 5'b01000) begin
          bus_write_address <= {store_location[31:2], 2'b00};
        end else begin
          bus_write_address <= 0;
        end

        // Note: Opcode is 6:0, but 1:0 seems to always be 0b11
        case (opcode[6:2])
          // R-Format instructions (register operations)
          // Register/register arithmetic/logic operations
          5'b01100: begin
            case (funct3)
              0: if (!funct7[5]) begin
                rd_value <= rs1_value + rs2_value;  // add
              end else begin
                rd_value <= rs1_value - rs2_value;  // sub
              end
              // TODO:
              // 1: sll
              2: rd_value <= (rs1_value < rs2_value) ? 1 : 0;  // slt
              3: rd_value <= (rs1_value_unsigned < rs2_value_unsigned) ? 1 : 0;  // sltu
              4: rd_value <= rs1_value ^ rs2_value;  // xor
              // TODO:
              // 5: srl/sra
              6: rd_value <= rs1_value | rs2_value;  // or
              7: rd_value <= rs1_value & rs2_value;  // and
              default: begin
                rd_value <= {32{1'bx}};
                exception <= 1;
              end
            endcase
          end

          // I-Format instructions (immediate operations)
          // Register/immediate arithmetic/logic operations
          5'b00100: begin
            case (funct3)
              0: rd_value <= rs1_plus_imm12;  // addi
              2: rd_value <= (rs1_value < imm12_value) ? 1 : 0;  // slti
              3: rd_value <= (rs1_value < imm12_value_unsigned) ? 1 : 0;  // sltiu
              4: rd_value <= rs1_value ^ imm12_value;  // xori
              6: rd_value <= rs1_value | imm12_value;  // ori
              7: rd_value <= rs1_value & imm12_value;  // andi
              default: begin
                rd_value <= {32{1'bx}};
                exception <= 1;
              end
            endcase
          end
          // Unconditional jump to register + small immediate offset
          5'b11001: begin
            // TODO: check sizes
            jump_target <= rs1_plus_imm12[31:2];  // jalr
            rd_value <= {jump_target, 2'b00};
          end
          // Load value from RAM into register
          5'b00000: begin
            load_word = bus_read_data;

            if (opcode[1:0] == 0) begin
              exception <= 1;
            end

            case (funct3)
              // Load byte
              0: case (load_location[1:0])
                0: rd_value <= {{24{load_word[7]}}, load_word[7:0]};
                1: rd_value <= {{24{load_word[15]}}, load_word[15:8]};
                2: rd_value <= {{24{load_word[23]}}, load_word[23:16]};
                3: rd_value <= {{24{load_word[31]}}, load_word[31:24]};
              endcase
              // Load half-word
              1: case (load_location[1:0])
                0: rd_value <= {{16{load_word[15]}}, load_word[15:0]};
                2: rd_value <= {{16{load_word[31]}}, load_word[31:16]};
                default: exception <= 1;
              endcase
              // Load word
              2: rd_value <= load_word;
              // Load byte unsigned
              4: case (load_location[1:0])
                0: rd_value <= {{24{0}}, load_word[7:0]};
                1: rd_value <= {{24{0}}, load_word[15:8]};
                2: rd_value <= {{24{0}}, load_word[23:16]};
                3: rd_value <= {{24{0}}, load_word[31:24]};
              endcase
              // Load half-word unsigned
              5: case (load_location[1:0])
                0: rd_value <= {{16{0}}, load_word[15:0]};
                2: rd_value <= {{16{0}}, load_word[31:16]};
                default: exception <= 1;
              endcase
            endcase
          end

          // U-Format instructions (upper-immediate)
          // Load upper-immediate
          5'b01101: begin
            rd_value <= {imm20_u, {12{1'b0}}};  // lui
          end
          // Add upper-immediate to program counter
          5'b00101: begin
            rd_value <= {imm20_u, 12'b0} + {program_counter, 2'b0};  // auipc
          end

          // J-Format instructions (jumps)
          // Unconditional jump to large immediate offset
          5'b11011: begin
            // TODO: check sizes
            jump_target <= program_counter + imm20_j[21:3];  // jal
            rd_value <= {jump_target, 2'b00};
          end

          // B-Format instructions (branches)
          // Branch (jump) to small immediate offset on condition
          5'b11000: begin
            branch_target <= program_counter + imm12_b[11:1];

            // TODO: Use last bit for negation
            case (funct3)
              0: branch_condition <= rs1_value == rs2_value;  // beq
              1: branch_condition <= rs1_value != rs2_value;  // bne
              4: branch_condition <= rs1_value < rs2_value;  // blt
              5: branch_condition <= rs1_value >= rs2_value;  // bge
              6: branch_condition <= rs1_value_unsigned < rs2_value_unsigned;  // bltu
              7: branch_condition <= rs1_value_unsigned >= rs2_value_unsigned;  // bgeu
              default: exception <= 1;
            endcase
          end

          // S-Format instructions (stores)
          // Store value from register into RAM
          5'b01000: begin
            load_word = bus_read_data;

            case (funct3)
              // Store byte
              0: begin
                case (store_location[1:0])
                  0: bus_write_data <= {load_word[31:8], rs2_value[7:0]};
                  1: bus_write_data <= {load_word[31:16], rs2_value[7:0], load_word[7:0]};
                  2: bus_write_data <= {load_word[31:24], rs2_value[7:0], load_word[15:0]};
                  3: bus_write_data <= {rs2_value[7:0], load_word[23:0]};
                endcase
              end
              // Store half-word
              1: begin
                case (store_location[1:0])
                  0: bus_write_data <= {load_word[31:16], rs2_value[15:0]};
                  2: bus_write_data <= {load_word[31:16], rs2_value[15:0]};
                endcase
              end
              // Store word
              2: begin
                bus_write_data <= rs2_value;
              end
              3: exception <= 1;
            endcase
          end
          // Unknown opcode
          default: begin
            rd_value <= {32{1'bx}};  // Set result to undefined, aka "don't care"
            exception <= 1;
          end
        endcase
      end
      // Stage 3 - store result of operation and program counter
      5: begin
        if (branch_condition) begin
          program_counter <= branch_target;
        end else begin
          program_counter <= jump_target;
        end
        registers[rd] <= rd_value;
        bus_read_address <= 0;
        bus_write_address <= 0;
        stage <= 0;
      end
    endcase
  end
endmodule
