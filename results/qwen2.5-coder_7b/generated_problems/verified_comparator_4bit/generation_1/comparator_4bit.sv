module comparator_4bit (
    input [3:0] A,          // First 4-bit input operand
    input [3:0] B,          // Second 4-bit input operand
    output reg A_greater,   // Output indicating if A is greater than B
    output reg A_equal,     // Output indicating if A is equal to B
    output reg A_less         // Output indicating if A is less than B
);

// Internal signals for subtraction and borrow generation
wire [3:0] diff;          // Result of A - B
wire carry_out;            // Borrow out from the most significant bit

// Perform 4-bit subtraction using a subtractor module or logic
assign {carry_out, diff} = A - B;

// Determine the outputs based on the subtraction result and borrow
always @(*) begin
    if (diff == 0) begin
        A_greater = 1'b0;
        A_equal   = 1'b1;
        A_less    = 1'b0;
    end else if (carry_out) begin
        A_greater = 1'b0;
        A_equal   = 1'b0;
        A_less    = 1'b1;
    end else begin
        A_greater = 1'b1;
        A_equal   = 1'b0;
        A_less    = 1'b0;
    end
end

endmodule
