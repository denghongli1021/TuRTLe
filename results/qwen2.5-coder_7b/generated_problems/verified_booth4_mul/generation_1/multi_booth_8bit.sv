module multi_booth_8bit (
    input wire clk,
    input wire reset,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [15:0] p,
    output reg rdy
);

reg [15:0] multiplier;
reg [15:0] multiplicand;
reg [4:0] ctr; // Counter for Booth algorithm

// Initialize registers on reset
always @(posedge clk or posedge reset) begin
    if (reset) begin
        p <= 16'b0;
        rdy <= 0;
        multiplier <= {{8{a[7]}}, a};
        multiplicand <= {{8{b[7]}}, b};
        ctr <= 5'b0;
    end else begin
        // Booth algorithm logic
        if (ctr < 16) begin
            multiplicand <= {multiplicand[14:0], 1'b0}; // Left shift multiplicand

            if (multiplier[ctr] == 2'b11) begin
                p <= p + multiplicand; // Add multiplicand to product if multiplier bit is 11
            end else if (multiplier[ctr] == 2'b01) begin
                p <= p - multiplicand; // Subtract multiplicand from product if multiplier bit is 01
            end

            ctr <= ctr + 1; // Increment counter
        end else begin
            rdy <= 1; // Set ready signal when multiplication is complete
        end
    end
end

endmodule
