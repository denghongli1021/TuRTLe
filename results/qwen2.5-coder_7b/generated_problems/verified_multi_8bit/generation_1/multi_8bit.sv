module multi_8bit (
    input [7:0] A,          // First 8-bit input operand (multiplicand)
    input [7:0] B,          // Second 8-bit input operand (multiplier)
    output reg [15:0] product // 16-bit output representing the product
);

integer i;

always @(*) begin
    product = 16'b0; // Initialize product to zero

    for (i = 0; i < 8; i = i + 1) begin
        if (B[i]) begin
            product = product + (A << i); // Shift A left by i and add to product
        end
    end
end

endmodule
