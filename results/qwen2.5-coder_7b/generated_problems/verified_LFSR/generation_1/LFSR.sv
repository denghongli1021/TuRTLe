module LFSR (
    input wire clk,          // Clock signal
    input wire rst,          // Active high reset signal
    output reg [3:0] out     // 4-bit output representing the current state of the LFSR
);

// Internal register to hold the LFSR state
reg [3:0] lfsr_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Initialize the register to zero on reset
        lfsr_reg <= 4'b0000;
    end else begin
        // Shift the bits left and apply feedback
        lfsr_reg[3] <= lfsr_reg[2];
        lfsr_reg[2] <= lfsr_reg[1];
        lfsr_reg[1] <= lfsr_reg[0];
        
        // Feedback is XOR of the most significant bit (out[3]) and the second most significant bit (out[2])
        lfsr_reg[0] <= ~ (lfsr_reg[3] ^ lfsr_reg[2]);
    end
end

// Assign the output to the current state of the LFSR register
assign out = lfsr_reg;

endmodule
