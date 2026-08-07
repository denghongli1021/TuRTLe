module ring_counter (
    input wire clk,          // Clock signal
    input wire reset,        // Reset signal
    output reg [7:0] out     // 8-bit output representing the current state of the ring counter
);

// Internal register to hold the current state of the ring counter
reg [7:0] state;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        // Initialize the state when reset is high
        state <= 8'b0000_0001;
    end else begin
        // Shift the bits to create a cyclic sequence
        state <= {state[6:0], state[7]};
    end
end

// Assign the output based on the current state of the ring counter
assign out = state;

endmodule
