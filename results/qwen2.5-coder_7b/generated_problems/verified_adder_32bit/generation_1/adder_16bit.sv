module adder_16bit (
    input [15:0] A,
    input [15:0] B,
    output reg [15:0] S,
    output reg C_out
);

    wire [15:0] G;
    wire [15:0] P;
    wire [14:0] C;

    // Generate the generate and propagate signals
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : generate_propagate_generate
            assign G[i] = A[i] & B[i];
            assign P[i] = A[i] | B[i];
        end
    endgenerate

    // Generate the carry signals using a ripple adder for the first stage
    assign C[0] = G[0];
    genvar j;
    generate
        for (j = 1; j < 16; j = j + 1) begin : ripple_carry_adder
            assign C[j] = G[j] | (P[j] & C[j-1]);
        end
    endgenerate

    // Generate the sum signals using the propagate and carry signals
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : adder_logic
            assign S[k] = P[k] ^ C[k];
        end
    endgenerate

    // Generate the final carry-out signal
    assign C_out = C[15];

endmodule
