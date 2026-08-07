module edge_detect (
    input wire clk,          // Clock signal
    input wire rst_n,        // Reset signal (active low)
    input wire a,            // Input signal
    output reg rise,         // Output signal indicating a rising edge
    output reg down          // Output signal indicating a falling edge
);

reg a_prev;                // Previous value of the input signal

// Synchronous reset block
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rise <= 0;
        down <= 0;
        a_prev <= 0;
    end else begin
        // Detect rising edge
        if (a_prev == 0 && a == 1) begin
            rise <= 1;
            down <= 0;
        end else if (a_prev == 1 && a == 0) begin
            rise <= 0;
            down <= 1;
        end else begin
            rise <= 0;
            down <= 0;
        end

        // Update previous value of the input signal
        a_prev <= a;
    end
end

endmodule
