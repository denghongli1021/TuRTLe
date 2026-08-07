module freq_divbyodd #(
    parameter NUM_DIV = 5 // Default divisor value
) (
    input wire clk,        // Input clock signal
    input wire rst_n,      // Active low reset signal
    output reg clk_div     // Divided clock output
);

// Internal counters for tracking rising and falling edges
reg [NUM_DIV-2:0] cnt1;  // Counter for rising edge
reg [NUM_DIV-2:0] cnt2;  // Counter for falling edge

// Internal signals for toggling the clock dividers
reg clk_div1;
reg clk_div2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset counters and outputs
        cnt1 <= 0;
        cnt2 <= 0;
        clk_div1 <= 0;
        clk_div2 <= 0;
        clk_div <= 0;
    end else begin
        // Count rising edge
        if (clk_div1 == 0) begin
            cnt1 <= cnt1 + 1;
            if (cnt1 == NUM_DIV / 2 - 1) begin
                clk_div1 <= ~clk_div1;
                cnt1 <= 0;
            end
        end

        // Count falling edge
        if (clk_div2 == 0) begin
            cnt2 <= cnt2 + 1;
            if (cnt2 == NUM_DIV / 2 - 1) begin
                clk_div2 <= ~clk_div2;
                cnt2 <= 0;
            end
        end

        // Combine the two clock dividers
        clk_div <= clk_div1 | clk_div2;
    end
end

endmodule
