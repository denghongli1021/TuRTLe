module right_shifter (
    input wire clk,          // Clock signal used for synchronous operation.
    input wire d,            // Input signal to be right-shifted.
    output reg [7:0] q      // Output signal representing the result of the right shift operation.
);

// Initialize the register q to 0
initial begin
    q = 8'b0;
end

// Synchronous process for shifting and updating the register on each rising edge of the clock
always @(posedge clk) begin
    // Right-shift the contents of q by one bit
    q <= (q >> 1);
    
    // Insert the new input bit d into the most significant position of the register
    q[7] <= d;
end

endmodule
