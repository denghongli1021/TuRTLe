module pe (
    input wire clk,          // Clock signal used for synchronous operations.
    input wire rst,          // Reset signal. Defined as 1 for reset and 0 for reset signal inactive.
    input wire [31:0] a,     // 32-bit input operand A.
    input wire [31:0] b,     // 32-bit input operand B.
    output reg [31:0] c      // 32-bit output representing the accumulated result.
);

// Always block to handle synchronous operations
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset condition: set the accumulator register to 0
        c <= 32'b0;
    end else begin
        // Accumulate the product of a and b into the accumulator register
        c <= c + (a * b);
    end
end

endmodule
