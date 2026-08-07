module counter_12 (
    input wire rst_n,      // Active low reset signal
    input wire clk,        // Clock signal
    input wire valid_count,  // Control signal to enable counting
    output reg [3:0] out   // 4-bit output representing the current count value
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset condition: counter is reset to 0 when rst_n is active (low)
        out <= 4'b0000;
    end else begin
        if (valid_count) begin
            // Increment the counter if valid_count is high
            if (out == 4'd11) begin
                // Wrap around and reset to 0 when reaching the maximum count value
                out <= 4'b0000;
            end else begin
                // Normal increment
                out <= out + 1;
            end
        end else begin
            // Counter stops if valid_count is low
            // Output remains unchanged
        end
    end
end

endmodule
