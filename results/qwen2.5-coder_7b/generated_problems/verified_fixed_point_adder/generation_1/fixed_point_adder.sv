module fixed_point_adder #(parameter Q = 8, parameter N = 16)
(
    input [N-1:0] a,
    input [N-1:0] b,
    output reg [N-1:0] c
);

    // Internal registers to store the result and intermediate values
    reg [N-1:0] res;
    wire sign_a = a[N-1];
    wire sign_b = b[N-1];

    // Extract integer and fractional parts
    wire [Q-1:0] frac_a = a[Q-1:0];
    wire [Q-1:0] frac_b = b[Q-1:0];
    wire [N-Q-1:0] int_a = a[N-Q-1:N-Q];
    wire [N-Q-1:0] int_b = b[N-Q-1:N-Q];

    // Absolute values of inputs
    reg [N-1:0] abs_a;
    reg [N-1:0] abs_b;

    assign abs_a = sign_a ? ~a + 1 : a;
    assign abs_b = sign_b ? ~b + 1 : b;

    // Perform addition or subtraction based on signs
    always @(*) begin
        if (sign_a == sign_b) begin
            // Both numbers have the same sign, perform addition
            res = int_a + int_b + {N-Q{frac_a + frac_b}};
        end else begin
            // Numbers have different signs, perform subtraction
            if (abs_a >= abs_b) begin
                res = int_a - int_b + {N-Q{frac_a - frac_b}};
                sign_a ? c[N-1] = 0 : c[N-1] = 1;
            end else begin
                res = int_b - int_a + {N-Q{frac_b - frac_a}};
                sign_b ? c[N-1] = 0 : c[N-1] = 1;
            end
        end

        // Handle overflow by checking the MSB
        if (res[N-1]) begin
            c = res & ~(
