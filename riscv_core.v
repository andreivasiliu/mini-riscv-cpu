module riscv_core(
    input clk,
    input rst,
    output reg [23:0] out24,
    output reg [7:0] out8,
  );

  reg [1:0] stage;
  reg [31:0] instruction;
  reg [29:0] program_counter, jump_target, branch_target;
  reg branch_condition;
  reg exception;

  reg [31:0] memory [0:1023];
  reg [31:0] registers [0:31];

  wire [6:0] opcode, funct7;
  wire [4:0] rd, rs1, rs2;
  wire [2:0] funct3;
  wire [11:0] imm12;
  wire signed [11:0] imm12_b = {
    instruction[31], instruction[7], instruction[30:25], instruction[11:8]
  };
  // TODO: Check operations on non :0 wires
  wire [31:12] imm20_u = instruction[31:12];
  wire signed [21:2] imm20_j = {
    instruction[31], instruction[19:12], instruction[20], instruction[30:21]
  };
  wire signed [11:0] store_offset = {instruction[31:25], instruction[11:7]};
  wire signed [11:0] load_offset = instruction[31:20];
  assign opcode = instruction[6:0];
  assign rd = instruction[11:7];
  assign funct3 = instruction[14:12];
  assign rs1 = instruction[19:15];
  assign rs2 = instruction[24:20];
  assign funct7 = instruction[31:25];
  assign imm12 = instruction[31:20];

  reg signed [31:0] rs1_value, rs2_value, rd_value;
  reg signed [31:0] imm12_value, store_word, load_word;
  reg [31:0] store_location, load_location;

  wire [31:0] rs1_value_unsigned, rs2_value_unsigned, imm12_value_unsigned;
  assign rs1_value_unsigned = rs1_value;
  assign rs2_value_unsigned = rs2_value;
  assign imm12_value_unsigned = imm12_value;

  wire [31:0] rs1_plus_imm12 = rs1_value + imm12_value;


  initial begin
    $readmemh("program.hex", memory);
  end

  always @(posedge clk) begin
    stage <= stage + 1;

    case (stage)
      0: begin
        instruction <= memory[program_counter];
        registers[0] <= 32'b0;
        jump_target <= program_counter + 1;
        branch_condition <= 0;
        exception <= 0;
      end
      1: begin
        rs1_value <= registers[rs1];
        rs2_value <= registers[rs2];
        imm12_value <= {{20{imm12[11]}}, imm12};
        store_location <= registers[rs1] + store_offset;
        load_location <= registers[rs1] + load_offset;
        // store_word <= memory[registers[rs1] + store_offset];
        // load_word <= memory[registers[rs1] + load_offset];
      end
      2: begin
        case (opcode[6:2])
          // R-Format instructions (register operations)
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
          5'b11001: begin
            // TODO: check sizes
            jump_target <= rs1_plus_imm12[31:2];  // jalr
            rd_value <= {jump_target, 2'b00};
          end
          5'b00000: begin
            load_word = memory[load_location[31:2]];

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
          5'b01101: begin
            rd_value <= {imm20_u, {12{1'b0}}};  // lui
          end
          5'b00101: begin
            rd_value <= {imm20_u, 12'b0} + {program_counter, 2'b0};  // auipc
          end

          // J-Format instructions (jumps)
          5'b11011: begin
            // TODO: check sizes
            jump_target <= program_counter + imm20_j[21:3];  // jal
            rd_value <= {jump_target, 2'b00};
          end

          // B-Format instructions (branches)
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
          5'b01000: begin
            store_word = memory[store_location[31:2]];

            case (funct3)
              // Store byte
              0: begin
                case (store_location[1:0])
                  0: memory[store_location[31:2]] <= {store_word[31:8], rs2_value[7:0]};
                  1: memory[store_location[31:2]] <= {store_word[31:16], rs2_value[7:0], store_word[7:0]};
                  2: memory[store_location[31:2]] <= {store_word[31:24], rs2_value[7:0], store_word[15:0]};
                  3: memory[store_location[31:2]] <= {rs2_value[7:0], store_word[23:0]};
                endcase
              end
              // Store half-word
              1: begin
                case (store_location[1:0])
                  0: memory[store_location[31:2]] <= {store_word[31:16], rs2_value[15:0]};
                  2: memory[store_location[31:2]] <= {store_word[31:16], rs2_value[15:0]};
                endcase
              end
              // Store word
              2: begin
                memory[store_location[31:2]] <= rs2_value;
              end
              3: exception <= 1;
            endcase
          end
          default: begin
            rd_value <= {32{1'bx}};
            exception <= 1;
          end
        endcase
      end
      3: begin
        if (branch_condition) begin
          program_counter <= branch_target;
        end else begin
          program_counter <= jump_target;
        end
        registers[rd] <= rd_value;
        // out <= {exception, program_counter[6:0], memory[512][7:0], registers[10][7:0]};
        out24 <= {exception, program_counter[6:0], instruction[15:0]};
        out8 <= memory[512][7:0];
      end
    endcase
  end
endmodule
