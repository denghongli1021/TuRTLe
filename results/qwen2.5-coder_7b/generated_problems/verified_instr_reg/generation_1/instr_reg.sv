module instr_reg (
    input wire clk,          // Clock signal for synchronization
    input wire rst_n,        // Active low reset signal to initialize the register
    input wire [1:0] fetch,  // Control signal indicating the source of the instruction (1 for register, 2 for RAM/ROM)
    input wire [7:0] data,   // 8-bit data input representing the instruction to be fetched

    output reg [2:0] ins,    // High 3 bits of the instruction, indicating the opcode or operation
    output reg [4:0] ad1,    // Low 5 bits of the instruction, representing the register address
    output reg [7:0] ad2     // The full 8-bit data from the second source
);

    reg [7:0] ins_p1;        // First instruction register
    reg [7:0] ins_p2;        // Second instruction register

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize both registers to zero on reset
            ins_p1 <= 8'b0;
            ins_p2 <= 8'b0;
        end else begin
            case (fetch)
                2'b01: begin
                    // Fetch instruction from data input into ins_p1
                    ins_p1 <= data;
                end
                2'b10: begin
                    // Fetch instruction from data input into ins_p2
                    ins_p2 <= data;
                end
                default: begin
                    // Retain previous values if neither condition is met
                end
            endcase
        end
    end

    // Derive outputs from the stored instructions
    always @(*) begin
        case (fetch)
            2'b01: begin
                ins = ins_p1[2:0];
                ad1 = ins_p1[4:0];
                ad2 = 8'b0;
            end
            2'b10: begin
                ins = ins_p2[2:0];
                ad1 = ins_p2[4:0];
                ad2 = data; // Use the full 8-bit data from the second source
            end
            default: begin
                ins = 3'b0;
                ad1 =
