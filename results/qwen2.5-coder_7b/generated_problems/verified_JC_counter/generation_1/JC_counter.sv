module JC_counter (
    input wire clk,          // Clock signal used for synchronous operation.
    input wire rst_n,        // Active-low reset signal to initialize the counter.
    output reg [63:0] Q     // 64-bit register representing the current count value.
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset condition: set all bits of Q to 0
        Q <= 64'b0;
    end else begin
        if (Q[0] == 1'b0) begin
            // Increment: shift right and append a 1 at the most significant bit position
            Q <= {Q[62:0], 1'b1};
        end else begin
            // Decrement: shift right and append a 0 at the most significant bit position
            Q <= {Q[62:0], 1'b0};
        end
    end
end

endmodule
