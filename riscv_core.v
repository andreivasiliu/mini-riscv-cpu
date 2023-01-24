module riscv_core(
    input clk,
    input rst,
    output reg [31:0] out,
  );

  reg [1:0] stage;
  reg [31:0] program_counter, instruction;

  reg [31:0] memory [0:1023];
  reg [31:0] registers [0:31];

  wire [6:0] opcode, funct7;
  wire [4:0] rd, rs1, rs2;
  wire [2:0] funct3;
  wire [11:0] imm12;
  wire [11:0] store_offset;
  assign opcode = instruction[6:0];
  assign rd = instruction[11:7];
  assign funct3 = instruction[14:12];
  assign rs1 = instruction[19:15];
  assign rs2 = instruction[24:20];
  assign funct7 = instruction[31:25];
  assign imm12 = instruction[31:20];
  assign store_offset = {instruction[31:25], instruction[11:7]};

  reg signed [31:0] rs1_value, rs2_value, rd_value;
  reg signed [31:0] imm12_value, store_word;
  reg [31:0] store_location;

  wire [31:0] rs1_value_unsigned, rs2_value_unsigned, imm12_value_unsigned;
  assign rs1_value_unsigned = rs1_value;
  assign rs2_value_unsigned = rs2_value;
  assign imm12_value_unsigned = imm12_value;


  initial begin
    memory[0] <= 1;
    memory[1] <= 2;
  end

  always @(posedge clk) begin
    stage <= stage + 1;
    out <= program_counter[23:0] | registers[0][23:0];

    case (stage)
      0: instruction <= memory[program_counter];
      1: begin
        rs1_value <= registers[rs1];
        rs2_value <= registers[rs2];
        imm12_value <= {{20{imm12[11]}}, imm12};
        store_location <= registers[rs1] + store_offset;
        
        // registers[rd] <= registers[rs1] + registers[rs2];
      end
      2: begin
        case (opcode[6:2])
          // R-Format instruction (register operations)
          7'b01100: begin
            case (funct3)
              0: rd_value <= rs1_value + rs2_value;  // add
              // 0: sub
              // 1: sll
              2: rd_value <= (rs1_value < rs2_value) ? 1 : 0;  // slt
              3: rd_value <= (rs1_value_unsigned < rs2_value_unsigned) ? 1 : 0;  // sltu
              4: rd_value <= rs1_value ^ rs2_value;  // xor
              // 5: srl/sra
              6: rd_value <= rs1_value | rs2_value;  // or
              7: rd_value <= rs1_value & rs2_value;  // and
              default: rd_value <= {32{1'bx}};
            endcase
          end
          // I-Format instruction (immediate operations)
          7'b00100: begin
            case (funct3)
              0: rd_value <= rs1_value + imm12_value;  // addi
              2: rd_value <= (rs1_value < imm12_value) ? 1 : 0;  // slti
              3: rd_value <= (rs1_value < imm12_value_unsigned) ? 1 : 0;  // sltiu
              4: rd_value <= rs1_value ^ imm12_value;  // xori
              6: rd_value <= rs1_value | imm12_value;  // ori
              7: rd_value <= rs1_value & imm12_value;  // andi
              default: rd_value <= {32{1'bx}};
            endcase
          end
          // S-Format instruction (stores)
          7'b1000: begin
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
            endcase
          end
          default: rd_value <= {32{1'bx}};
        endcase
      end
      3: begin
        program_counter <= program_counter + 1;
        registers[rd] <= rd_value;
      end
    endcase
  end
endmodule
