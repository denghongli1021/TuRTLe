module adder_8bit (
    input [7:0] a,
    input [7:0] b,
    input Cin,
    output reg [7:0] y,
    output reg Co
);

    // Instantiate two 1-bit full adders for each bit position
    wire [7:0] carry_out;
    wire [7:0] sum;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : bit_adder
            assign {carry_out[i], sum[i]} = a[i] + b[i] + Cin;
            assign Cin = carry_out[i];
        end
    endgenerate

    // Assign the final output and carry-out
    assign y = sum;
    assign Co = carry_out[7];

endmodule

module adder_16bit (
    input [15:0] a,
    input [15:0] b,
    input Cin,
    output reg [15:0] y,
    output reg Co
);

    // Instantiate two 8-bit full adders
    wire [7:0] sum_low;
    wire carry_out_low;
    wire [7:0] sum_high;
    wire carry_out_high;

    adder_8bit low_adder (
        .a(a[7:0]),
        .b(b[7:0]),
        .Cin(Cin),
        .y(sum_low),
        .Co(carry_out_low)
    );

    adder_8bit high_adder (
        .a(a[15:8]),
        .b(b[15:8]),
        .Cin(carry_out_low),
        .y(sum_high),
        .Co(carry_out_high)
    );

    // Assign the final output and carry-out
    assign y = {sum_high, sum_low};
    assign Co = carry_out_high;

endmodule
