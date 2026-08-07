module barrel_shifter (
    input [7:0] in,          // 8-bit input to be shifted
    input [2:0] ctrl,        // 3-bit control signal for shift amount
    output reg [7:0] out     // 8-bit shifted output
);

// Submodule for 2-to-1 multiplexer
module mux2X1 (
    input sel,
    input a,
    input b,
    output reg y
);
    always @(*) begin
        if (sel)
            y = a;
        else
            y = b;
    end
endmodule
