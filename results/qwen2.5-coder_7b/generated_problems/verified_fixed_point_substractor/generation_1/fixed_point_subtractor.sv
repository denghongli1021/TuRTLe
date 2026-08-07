module fixed_point_subtractor #(
    parameter Q = 8,
    parameter N = 16
)(
    input wire [N-1:0] a,
    input wire [N-1:0] b,
    output reg [N-1:0] c
);

    // Internal registers for intermediate calculations
    reg [N-1:0] abs_a;
    reg [N-1:0] abs_b;
    reg [N-1:0] res;

    // Extract the sign bit from inputs
    wire a_sign = a[N-1];
    wire b_sign = b[N-1];

    // Extract the fractional and integer parts of inputs
    assign abs_a = a & ~(1 << (N - 1));
    assign abs_b = b & ~(1 << (N - 1));

    always @(*) begin
        if (a_sign == b_sign) begin
            // Same sign subtraction
            res = abs_a - abs_b;
            c[N-1] = a_sign; // Sign of the result is the same as inputs
        end else begin
            // Different sign subtraction
            if (abs_a > abs_b) begin
                res = abs_a + abs_b;
                c[N-1] = 0; // Result is positive
            end else begin
                res = abs_b - abs_a;
                c[N-1] = 1; // Result is negative
            end
        end

        // Handle zero case explicitly
        if (res == 0) begin
            c[N-1] = 0; // Sign of the result is positive for zero
        end
    end

    assign c[N-2:0] = res[N-2:0]; // Assign fractional part to output

endmodule
