module adder_8bit (
    input [7:0] a,          // 8-bit input operand A
    input [7:0] b,          // 8-bit input operand B
    input cin,              // Carry-in input
    output reg [7:0] sum,   // 8-bit output representing the sum of A and B
    output reg cout         // Carry-out output
);

// Full adder component definition
module full_adder (
    input a,
    input b,
    input cin,
    output reg sum,
    output reg cout
);
    assign {cout, sum} = a + b + cin;
endmodule

// Instantiate 8 full adders to build the 8-bit adder
full_adder fa0 (a[0], b[0], cin, sum[0], cout);
full_adder fa1 (a[1], b[1], cout, sum[1], cout);
full_adder fa2 (a[2], b[2], cout, sum[2], cout);
full_adder fa3 (a[3], b[3], cout, sum[3], cout);
full_adder fa4 (a[4], b[4], cout, sum[4], cout);
full_adder fa5 (a[5], b[5], cout, sum[5], cout);
full_adder fa6 (a[6], b[6], cout, sum[6], cout);
full_adder fa7 (a[7], b[7], cout, sum[7], cout);

endmodule
