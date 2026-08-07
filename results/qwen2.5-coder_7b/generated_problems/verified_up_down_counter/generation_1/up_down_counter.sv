module up_down_counter (
    input wire clk,          // Clock signal (1-bit)
    input wire reset,        // Reset signal (1-bit)
    input wire up_down,      // Control signal (1-bit)
    output reg [15:0] count  // 16-bit output representing the current counter value
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        count <= 16'b0;  // Reset the counter to zero
    end else begin
        if (up_down) begin
            count <= count + 1;  // Increment the counter
        end else begin
            count <= count - 1;  // Decrement the counter
        end
    end
end

endmodule
