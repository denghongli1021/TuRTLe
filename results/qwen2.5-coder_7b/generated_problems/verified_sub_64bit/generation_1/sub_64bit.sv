module sub_64bit (
    input [63:0] A,
    input [63:0] B,
    output reg [63:0] result,
    output reg overflow
);

// Perform the subtraction
assign {overflow, result} = $signed(A) - $signed(B);

endmodule
