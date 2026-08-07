module alu (
    input [31:0] a,
    input [31:0] b,
    input [5:0] aluc,
    output reg [31:0] r,
    output reg zero,
    output reg carry,
    output reg negative,
    output reg overflow,
    output reg flag
);

parameter ADD = 6'b100000;
parameter ADDU = 6'b100001;
parameter SUB = 6'b100010;
parameter SUBU = 6'b100011;
parameter AND = 6'b100100;
parameter OR = 6'b100101;
parameter XOR = 6'b100110;
parameter NOR = 6'b100111;
parameter SLT = 6'b101010;
parameter SLTU = 6'b101011;
parameter SLL = 6'b000000;
parameter SRL = 6'b000010;
parameter SRA = 6'b000011;
parameter SLLV = 6'b000100;
parameter SRLV = 6'b000110;
parameter SRAV = 6'b000111;
parameter LUI = 6'b001111;

reg [31:0] res;
wire signed_a, signed_b, signed_res;

assign signed_a = $signed(a);
assign signed_b = $signed(b);

always @(*) begin
    zero = 1'b0;
    carry = 1'b0;
    negative = 1'b0;
    overflow = 1'b0;
    flag = 1'b0;
    r = 32'b0;

    case (aluc)
        ADD: begin
            res = signed_a + signed_b;
            zero = (res == 32'b0);
            negative = (res[31] == 1'b1);
            overflow = ((signed_a[31] == signed_b[31]) && (signed_res[31] != signed_a[31]));
        end
        ADDU: begin
