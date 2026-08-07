module div_16bit (
    input wire [15:0] A,  // 16-bit dividend
    input wire [7:0] B,   // 8-bit divisor
    output reg [15:0] result,  // 16-bit quotient
    output reg [15:0] odd     // 16-bit remainder
);

reg [23:0] a_reg;  // Register to hold the dividend (A) with extra bits for shifting
reg [7:0] b_reg;   // Register to hold the divisor (B)

always @(*) begin
    a_reg = {8'b0, A};  // Initialize a_reg with A and extra 8 bits set to 0
    b_reg = B;          // Initialize b_reg with B

    result = 16'b0;     // Initialize quotient to 0
    odd = 16'b0;        // Initialize remainder to 0

    for (int i = 15; i >= 0; i--) begin
        if (a_reg[23:8] >= b_reg) begin
            a_reg[23:8] = a_reg[23:8] - b_reg;
            result[i] = 1;
        end else begin
            result[i] = 0;
        end
        a_reg = {a_reg[7], a_reg[23:1]};
    end

    odd = a_reg[23:8];
end

endmodule
