module comparator_3bit (
    input [2:0] A,          // First 3-bit input operand
    input [2:0] B,          // Second 3-bit input operand
    output reg A_greater,   // Output indicating if A is greater than B
    output reg A_equal,     // Output indicating if A is equal to B
    output reg A_less         // Output indicating if A is less than B
);

always @(*) begin
    if (A > B) begin
        A_greater = 1;
        A_equal = 0;
        A_less = 0;
    end else if (A < B) begin
        A_greater = 0;
        A_equal = 0;
        A_less = 1;
    end else begin
        A_greater = 0;
        A_equal = 1;
        A_less = 0;
    end
end

endmodule
