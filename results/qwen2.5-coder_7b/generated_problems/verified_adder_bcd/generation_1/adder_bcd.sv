module adder_bcd (
    input [3:0] A,
    input [3:0] B,
    input Cin,
    output reg [3:0] Sum,
    output reg Cout
);

// Internal signals for binary addition and correction
reg [4:0] sum_bin;
wire bcd_overflow;

assign sum_bin = A + B + Cin;  // Binary addition of A, B, and Cin

// Determine if the sum exceeds 9 (binary 1001)
assign bcd_overflow = (sum_bin > 9);

// Correct the sum to be within the BCD range
always @(*) begin
    if (bcd_overflow) begin
        Sum = sum_bin + 6;  // Add correction of 6 (binary 0110)
    end else begin
        Sum = sum_bin;
    end
end

// Generate carry-out
assign Cout = bcd_overflow;

endmodule
